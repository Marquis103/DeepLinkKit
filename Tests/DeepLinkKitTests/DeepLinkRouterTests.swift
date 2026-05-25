//
//  DeepLinkRouterTests.swift
//
//  Copyright © 2026 DeepLinkKit. All rights reserved.
//

import XCTest
@testable import DeepLinkKit

final class DeepLinkRouterTests: XCTestCase {

    // MARK: - Recorder

    /// Captures what the registered handler saw. Class so closures
    /// can mutate state across the actor hop.
    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _calls: [DeepLink] = []
        var calls: [DeepLink] {
            lock.lock(); defer { lock.unlock() }
            return _calls
        }
        func record(_ link: DeepLink) {
            lock.lock(); _calls.append(link); lock.unlock()
        }
    }

    // MARK: - Warm-path

    func test_warmHandleInvokesMatchingHandler() async throws {
        let router = DeepLinkRouter()
        let recorder = Recorder()
        await router.register(RoutePattern("/bill/{id}")) { link in
            recorder.record(link)
        }
        await router.signalReady()

        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR1-119"))
        try await router.handle(url: url, source: .universalLink)

        let calls = recorder.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.pathParameters["id"], "HR1-119")
        XCTAssertEqual(calls.first?.source, .universalLink)
    }

    func test_firstMatchWins() async throws {
        let router = DeepLinkRouter()
        let firstRecorder = Recorder()
        let secondRecorder = Recorder()
        // Register the more-specific pattern first so it wins
        // over the catch-all. Order matters — documented in the
        // router's class header.
        await router.register(RoutePattern("/bill/{id}")) { link in
            firstRecorder.record(link)
        }
        await router.register(RoutePattern("/{anything}")) { link in
            secondRecorder.record(link)
        }
        await router.signalReady()

        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR1-119"))
        try await router.handle(url: url, source: .universalLink)

        XCTAssertEqual(firstRecorder.calls.count, 1)
        XCTAssertEqual(secondRecorder.calls.count, 0)
    }

    // MARK: - Unmatched

    func test_unmatchedRouteThrows() async throws {
        let router = DeepLinkRouter()
        await router.register(RoutePattern("/bill/{id}")) { _ in }
        await router.signalReady()

        let url = try XCTUnwrap(URL(string: "https://ayes.app/totally-unknown"))

        do {
            try await router.handle(url: url, source: .universalLink)
            XCTFail("expected DeepLinkError.unmatchedRoute")
        } catch DeepLinkError.unmatchedRoute(let captured) {
            XCTAssertEqual(captured, url)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Cold-launch stash/replay

    func test_handleBeforeReadyStashesAndReplays() async throws {
        let router = DeepLinkRouter()
        let recorder = Recorder()

        // URL arrives BEFORE any handler is registered.
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR1-119"))
        try await router.handle(url: url, source: .universalLink)

        // No handlers yet — recorder should be empty + router
        // should have stashed.
        XCTAssertEqual(recorder.calls.count, 0)
        let stashedBefore = await router.hasStashedURL
        XCTAssertTrue(stashedBefore)

        // Register handler + flip ready — stashed URL replays.
        await router.register(RoutePattern("/bill/{id}")) { link in
            recorder.record(link)
        }
        await router.signalReady()

        XCTAssertEqual(recorder.calls.count, 1)
        XCTAssertEqual(recorder.calls.first?.pathParameters["id"], "HR1-119")
        let stashedAfter = await router.hasStashedURL
        XCTAssertFalse(stashedAfter)
    }

    func test_explicitStashThenSignalReady() async throws {
        let router = DeepLinkRouter()
        let recorder = Recorder()
        let url = try XCTUnwrap(URL(string: "https://ayes.app/share/abc"))

        await router.stash(url: url, source: .notification)
        await router.register(RoutePattern("/share/{token}")) { link in
            recorder.record(link)
        }
        await router.signalReady()

        XCTAssertEqual(recorder.calls.count, 1)
        XCTAssertEqual(recorder.calls.first?.pathParameters["token"], "abc")
        XCTAssertEqual(recorder.calls.first?.source, .notification)
    }

    func test_stashAfterReadyIsNoOp() async throws {
        let router = DeepLinkRouter()
        await router.signalReady()

        let url = try XCTUnwrap(URL(string: "https://ayes.app/whatever"))
        await router.stash(url: url)

        let stashed = await router.hasStashedURL
        XCTAssertFalse(stashed)
    }

    func test_concurrentHandleCallsAllLand() async throws {
        // Hardens the actor's serialization claim: 10 parallel
        // `handle()` calls should all execute the handler exactly
        // once each, in some serial order.
        let router = DeepLinkRouter()
        let recorder = Recorder()
        await router.register(RoutePattern("/bill/{id}")) { link in
            recorder.record(link)
        }
        await router.signalReady()

        let urls = (0..<10).compactMap { URL(string: "https://ayes.app/bill/HR\($0)") }
        XCTAssertEqual(urls.count, 10)

        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    try? await router.handle(url: url, source: .universalLink)
                }
            }
        }

        let ids = Set(recorder.calls.compactMap { $0.pathParameters["id"] })
        XCTAssertEqual(ids.count, 10)
        XCTAssertEqual(Set(ids), Set((0..<10).map { "HR\($0)" }))
    }

    func test_signalReadyReturnsReplayFailure() async throws {
        // Cold-launch URL that doesn't match any registered
        // pattern surfaces as `.failure` rather than being
        // silently swallowed. Hosts log + drop; the visibility
        // is what matters.
        let router = DeepLinkRouter()
        let url = try XCTUnwrap(URL(string: "https://ayes.app/totally-unknown"))
        try await router.handle(url: url, source: .universalLink)

        let result = await router.signalReady()
        guard case .failure(let error) = result else {
            XCTFail("expected .failure for unmatched stashed URL, got \(String(describing: result))")
            return
        }
        guard case DeepLinkError.unmatchedRoute(let captured) = error else {
            XCTFail("expected unmatchedRoute, got \(error)")
            return
        }
        XCTAssertEqual(captured, url)
    }

    func test_signalReadyTwiceIsSafe() async throws {
        let router = DeepLinkRouter()
        let recorder = Recorder()
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR1-119"))

        try await router.handle(url: url, source: .universalLink)
        await router.register(RoutePattern("/bill/{id}")) { link in
            recorder.record(link)
        }
        await router.signalReady()
        await router.signalReady() // second call should be a no-op

        // Handler fired exactly once on the first signalReady.
        XCTAssertEqual(recorder.calls.count, 1)
    }
}
