//
//  DeepLinkError.swift
//
//  Copyright © 2026 DeepLinkKit. All rights reserved.
//

import Foundation

// MARK: - DeepLinkError

/// Surfaced when `DeepLinkRouter.handle(url:)` can't act on an
/// incoming URL. The host app decides whether to log + drop, show
/// an unknown-link state, or kick to a generic search — the
/// router doesn't prescribe a fallback.
public enum DeepLinkError: Error, Sendable, Equatable {

    /// No registered `RoutePattern` matched. Carries the offending
    /// URL for logging.
    case unmatchedRoute(URL)
}
