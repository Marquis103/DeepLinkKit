//
//  RoutePatternTests.swift
//
//  Copyright © 2026 DeepLinkKit. All rights reserved.
//

import XCTest
@testable import DeepLinkKit

final class RoutePatternTests: XCTestCase {

    // MARK: - Static paths

    func test_staticPathMatchesExactly() throws {
        let pattern = RoutePattern("/watchlist")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/watchlist"))

        let link = try XCTUnwrap(pattern.match(url: url, source: .universalLink))
        XCTAssertEqual(link.pathParameters, [:])
        XCTAssertEqual(link.path, "/watchlist")
    }

    func test_staticPathMismatchReturnsNil() throws {
        let pattern = RoutePattern("/watchlist")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bills"))

        XCTAssertNil(pattern.match(url: url, source: .universalLink))
    }

    // MARK: - Captures

    func test_singleCaptureExtractsValue() throws {
        let pattern = RoutePattern("/bill/{id}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR1-119"))

        let link = try XCTUnwrap(pattern.match(url: url, source: .universalLink))
        XCTAssertEqual(link.pathParameters["id"], "HR1-119")
    }

    func test_multiCaptureExtractsAll() throws {
        let pattern = RoutePattern("/share/{token}/preview/{size}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/share/abc/preview/og"))

        let link = try XCTUnwrap(pattern.match(url: url, source: .universalLink))
        XCTAssertEqual(link.pathParameters["token"], "abc")
        XCTAssertEqual(link.pathParameters["size"], "og")
    }

    // MARK: - Segment-count rejections

    func test_extraSegmentDoesNotMatch() throws {
        let pattern = RoutePattern("/bill/{id}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR1-119/extra"))

        XCTAssertNil(pattern.match(url: url, source: .universalLink))
    }

    func test_missingSegmentDoesNotMatch() throws {
        let pattern = RoutePattern("/share/{token}/preview/{size}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/share/abc"))

        XCTAssertNil(pattern.match(url: url, source: .universalLink))
    }

    // MARK: - Query params

    func test_queryParametersExtracted() throws {
        let pattern = RoutePattern("/bill/{id}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR1-119?utm_source=twitter&ref=foo"))

        let link = try XCTUnwrap(pattern.match(url: url, source: .universalLink))
        XCTAssertEqual(link.pathParameters["id"], "HR1-119")
        XCTAssertEqual(link.parameters["utm_source"], "twitter")
        XCTAssertEqual(link.parameters["ref"], "foo")
    }

    // MARK: - Leading-slash forgiveness

    func test_templateWithoutLeadingSlashWorksToo() throws {
        let pattern = RoutePattern("bill/{id}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR1-119"))

        let link = try XCTUnwrap(pattern.match(url: url, source: .universalLink))
        XCTAssertEqual(link.pathParameters["id"], "HR1-119")
    }
}
