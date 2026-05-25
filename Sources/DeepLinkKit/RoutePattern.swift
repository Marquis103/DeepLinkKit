//
//  RoutePattern.swift
//
//  Copyright © 2026 DeepLinkKit. All rights reserved.
//

import Foundation

// MARK: - RoutePattern

/// A path template matched against an incoming URL. Static segments
/// are literal; `{name}` segments capture into `DeepLink.pathParameters`.
///
/// Examples:
///   * `RoutePattern("/bill/{id}")` matches `/bill/HR1-119` →
///     `["id": "HR1-119"]`
///   * `RoutePattern("/share/{token}/preview/{size}")` matches
///     `/share/abc/preview/og` → `["token": "abc", "size": "og"]`
///   * `RoutePattern("/watchlist")` matches `/watchlist` with no
///     captures
///
/// Matching is path-only — query parameters land in
/// `DeepLink.parameters` regardless of the pattern. The pattern
/// must match every path segment; partial matches return nil.
public struct RoutePattern: Sendable, Equatable {

    // MARK: - Nested

    /// One template segment. `literal` requires an exact string
    /// match; `capture` records the incoming segment under the
    /// given name.
    enum Part: Sendable, Equatable {
        case literal(String)
        case capture(String)
    }

    // MARK: - Properties

    public let template: String
    let parts: [Part]

    // MARK: - Lifecycle

    public init(_ template: String) {
        self.template = template
        self.parts = Self.parse(template: template)
    }

    // MARK: - Matching

    /// Attempt to match `url`'s path against this pattern. Returns
    /// a `DeepLink` with `pathParameters` populated, or nil if the
    /// segment count or any literal doesn't match.
    func match(url: URL, source: DeepLink.Source) -> DeepLink? {
        let segments = Self.pathSegments(of: url)
        guard segments.count == parts.count else { return nil }

        var pathParameters: [String: String] = [:]
        for (segment, part) in zip(segments, parts) {
            switch part {
            case .literal(let expected):
                if segment != expected { return nil }
            case .capture(let name):
                pathParameters[name] = segment
            }
        }

        return DeepLink(
            url: url,
            path: url.path,
            parameters: Self.queryParameters(of: url),
            pathParameters: pathParameters,
            source: source
        )
    }

    // MARK: - Private

    private static func parse(template: String) -> [Part] {
        // Strip leading slash so `/bill/{id}` and `bill/{id}` are
        // equivalent. Allows callers to register either shape
        // without worrying about subtle off-by-one bugs in `split`.
        let trimmed = template.hasPrefix("/") ? String(template.dropFirst()) : template
        return trimmed
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { segment -> Part in
                if segment.hasPrefix("{") && segment.hasSuffix("}") {
                    let name = String(segment.dropFirst().dropLast())
                    return .capture(name)
                }
                return .literal(String(segment))
            }
    }

    private static func pathSegments(of url: URL) -> [String] {
        let path = url.path
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return trimmed
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private static func queryParameters(of url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return [:]
        }
        // Duplicates collapse to the last-wins value — pragmatic
        // for a v1 router. Callers that need multi-value query keys
        // can read `url.query` directly and parse themselves.
        var result: [String: String] = [:]
        for item in items {
            if let value = item.value {
                result[item.name] = value
            }
        }
        return result
    }
}
