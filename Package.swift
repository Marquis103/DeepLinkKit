// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepLinkKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "DeepLinkKit",
            targets: ["DeepLinkKit"]
        )
    ],
    targets: [
        .target(
            name: "DeepLinkKit"
        ),
        .testTarget(
            name: "DeepLinkKitTests",
            dependencies: ["DeepLinkKit"]
        )
    ]
)
