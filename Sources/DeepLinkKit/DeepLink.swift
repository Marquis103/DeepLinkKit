//
//  DeepLink.swift
//
//  Copyright © 2026 DeepLinkKit. All rights reserved.
//

import Foundation

// MARK: - DeepLink

/// A parsed deep-link payload — what handlers actually receive after
/// `DeepLinkRouter.handle(url:)` matches a registered `RoutePattern`.
///
/// `pathParameters` carries the captured segments from a pattern
/// (e.g., `/bill/{id}` matched against `/bill/HR1-119` yields
/// `["id": "HR1-119"]`). `parameters` carries the URL's query
/// items — distinct so handlers can tell intent apart.
public struct DeepLink: Sendable, Equatable {

    // MARK: - Source

    /// Where the URL came from. Useful for analytics (universal
    /// links vs in-app schemes vs APNs payloads all hit the same
    /// handler but may want different telemetry).
    public enum Source: Sendable, Equatable {
        case universalLink
        case urlScheme
        case notification
    }

    // MARK: - Properties

    public let url: URL
    public let path: String
    public let parameters: [String: String]
    public let pathParameters: [String: String]
    public let source: Source

    // MARK: - Lifecycle

    public init(
        url: URL,
        path: String,
        parameters: [String: String],
        pathParameters: [String: String],
        source: Source
    ) {
        self.url = url
        self.path = path
        self.parameters = parameters
        self.pathParameters = pathParameters
        self.source = source
    }
}
