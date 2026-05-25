//
//  DeepLinkRouter.swift
//
//  Copyright © 2026 DeepLinkKit. All rights reserved.
//

import Foundation

// MARK: - DeepLinkRouter

/// Routes incoming URLs to registered handlers. Actor-isolated so
/// concurrent `handle(url:)` calls from multiple sources (universal
/// link, OS URL callback, APNs payload) serialize through one
/// registration table.
///
/// Cold-launch flow:
///   1. App delegate stashes the launch URL via `stash(url:)` before
///      anything is wired (no coordinator yet, no handlers registered)
///   2. App-startup orchestration finishes; root coordinator
///      registers patterns via `register(_:handler:)`
///   3. Coordinator calls `signalReady()` — router replays the stashed
///      URL through the now-populated handler table
///
/// Warm-launch (already-running app) flow:
///   * URL arrives → `handle(url:source:)` matches a registered
///     pattern and invokes its handler immediately
///
/// Registration order matters: handlers are checked first-to-last,
/// first match wins. Register more-specific patterns before
/// catch-alls.
public actor DeepLinkRouter {

    // MARK: - Properties

    private struct Registration {
        let pattern: RoutePattern
        let handler: @Sendable (DeepLink) async -> Void
    }

    private var registrations: [Registration] = []
    private var stashedURL: URL?
    private var stashedSource: DeepLink.Source?
    private var isReady: Bool = false

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Public API

    /// Register a handler for a path template. Handlers are
    /// `@Sendable` because they cross the actor boundary; capture
    /// only sendable references (most coordinators implement
    /// `Coordinating` which is class-bound — fine).
    public func register(
        _ pattern: RoutePattern,
        handler: @Sendable @escaping (DeepLink) async -> Void
    ) {
        registrations.append(Registration(pattern: pattern, handler: handler))
    }

    /// Process an incoming URL. If the router isn't ready
    /// (`signalReady()` hasn't been called yet), the URL is
    /// stashed for later replay — no throw, no log. Otherwise
    /// the URL is matched against registered patterns; the first
    /// match's handler runs and `handle` returns. If no pattern
    /// matches, throws `DeepLinkError.unmatchedRoute`.
    public func handle(
        url: URL,
        source: DeepLink.Source = .urlScheme
    ) async throws {
        if !isReady {
            stashedURL = url
            stashedSource = source
            return
        }
        try await route(url: url, source: source)
    }

    /// Explicit stash without attempting to handle. Useful when
    /// the app delegate sees a launch URL via
    /// `didFinishLaunchingWithOptions` and knows the router isn't
    /// wired yet — calling `stash` instead of `handle` skips the
    /// (futile) ready-check round-trip.
    public func stash(url: URL, source: DeepLink.Source = .urlScheme) {
        guard !isReady else { return }
        stashedURL = url
        stashedSource = source
    }

    /// Flip the router into the ready state and replay any stashed
    /// URL. Idempotent — calling twice is a no-op on the second
    /// call (stash is consumed by the first replay).
    public func signalReady() async {
        isReady = true
        guard let url = stashedURL else { return }
        let source = stashedSource ?? .urlScheme
        stashedURL = nil
        stashedSource = nil
        try? await route(url: url, source: source)
    }

    // MARK: - Internal (test surface)

    /// Exposed for `DeepLinkRouterTests` — production code doesn't
    /// need to introspect the stash.
    var hasStashedURL: Bool { stashedURL != nil }

    /// Same — for assertions on whether the router has been
    /// signaled ready.
    var ready: Bool { isReady }

    // MARK: - Private

    private func route(url: URL, source: DeepLink.Source) async throws {
        for registration in registrations {
            if let link = registration.pattern.match(url: url, source: source) {
                await registration.handler(link)
                return
            }
        }
        throw DeepLinkError.unmatchedRoute(url)
    }
}
