# DeepLinkKit

URL routing for the portfolio iOS apps. Takes an incoming URL (universal link, in-app URL scheme, or APNs notification payload) and dispatches it to a registered handler.

## Install

```swift
.package(url: "https://github.com/Marquis103/DeepLinkKit", from: "1.0.0")
```

## Quick start

```swift
import DeepLinkKit

let router = DeepLinkRouter()

// Register what URL patterns the app cares about.
await router.register(RoutePattern("/bill/{id}")) { link in
    let billId = link.pathParameters["id"]!
    await coordinator.openBill(id: billId)
}

await router.register(RoutePattern("/share/{token}")) { link in
    let token = link.pathParameters["token"]!
    await coordinator.openSharedCard(token: token)
}

// Flip the router on once handlers are registered. Stashed
// cold-launch URLs replay here.
await router.signalReady()

// Process URLs as they arrive.
try await router.handle(url: incoming, source: .universalLink)
```

## Cold launch

The router supports a stash-then-replay flow for URLs that arrive before the rest of the app is wired up:

1. App delegate sees a launch URL (e.g., `application(_:didFinishLaunchingWithOptions:)` carries one in `launchOptions[.url]`)
2. Before any handler is registered: `await router.stash(url:)` — non-throwing, queues for later
3. App startup finishes, root coordinator registers its patterns
4. Coordinator calls `await router.signalReady()` — the stashed URL replays through the now-populated handler table

If the same URL arrives after the router is ready, calling `stash` is a no-op (the router has already moved on); use `handle` for the warm-launch path.

## Route patterns

* Static segments match literally: `RoutePattern("/watchlist")` matches `/watchlist` only.
* `{name}` segments capture: `RoutePattern("/bill/{id}")` matches `/bill/HR1-119` and yields `["id": "HR1-119"]` in `DeepLink.pathParameters`.
* Multi-capture: `RoutePattern("/share/{token}/preview/{size}")` works.
* Segment count must match exactly — partial matches return nil.
* Query parameters land in `DeepLink.parameters` regardless of the pattern (duplicate keys collapse last-wins).

## What's NOT here

* Universal-link domain registration (that's the host app's AASA file + Associated Domains entitlement).
* APNs payload → URL conversion (that's NotificationsKit's job — see `NotificationsKit/DeepLink/Route.swift`).
* Background-fetch / handoff. SwiftUI's `NSUserActivity` continuation lives at the host's `.onContinueUserActivity` modifier; convert to a `URL` and hand to `router.handle`.
