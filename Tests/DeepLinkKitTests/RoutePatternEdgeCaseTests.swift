//
//  RoutePatternEdgeCaseTests.swift
//
//  Copyright © 2026 DeepLinkKit. All rights reserved.
//

import XCTest
@testable import DeepLinkKit

final class RoutePatternEdgeCaseTests: XCTestCase {

    func test_trailingSlashMatchesIdentically() throws {
        // `omittingEmptySubsequences: true` drops the trailing
        // empty segment, so `/bill/HR1-119/` matches `/bill/{id}`
        // the same as the unslashed form.
        let pattern = RoutePattern("/bill/{id}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR1-119/"))

        let link = try XCTUnwrap(pattern.match(url: url, source: .universalLink))
        XCTAssertEqual(link.pathParameters["id"], "HR1-119")
    }

    func test_barePrefixWithoutCaptureSegmentReturnsNil() throws {
        // `/bill/` has 1 path segment after stripping; pattern has
        // 2 parts (literal + capture) → mismatch, nil.
        let pattern = RoutePattern("/bill/{id}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/"))

        XCTAssertNil(pattern.match(url: url, source: .universalLink))
    }

    func test_urlEncodedCaptureDecodesViaURLPath() throws {
        // `URL.path` returns percent-decoded segments, so the
        // handler gets the human-readable string. If the raw
        // encoded form is ever needed, consumers can read
        // `link.url.absoluteString` directly.
        let pattern = RoutePattern("/bill/{id}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/bill/HR%201-119"))

        let link = try XCTUnwrap(pattern.match(url: url, source: .universalLink))
        XCTAssertEqual(link.pathParameters["id"], "HR 1-119")
    }

    func test_caseSensitiveLiteralMismatch() throws {
        // URL path comparison is case-sensitive (standard for the
        // `Equatable` String impl we use). Consumers that want
        // case-insensitive routes should lowercase before
        // constructing the pattern + URL.
        let pattern = RoutePattern("/bill/{id}")
        let url = try XCTUnwrap(URL(string: "https://ayes.app/Bill/HR1-119"))

        XCTAssertNil(pattern.match(url: url, source: .universalLink))
    }
}
