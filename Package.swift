// swift-tools-version:6.0
import PackageDescription

// Door 3 of stack-pack-ios: the dependency rule is the list of target dependencies below, so the compiler enforces it.
// No target imports SwiftUI, UIKit or WebKit: the views and the WKWebView glue live in the app (App/).
let package = Package(
    name: "PlutoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PlutoDomain", targets: ["PlutoDomain"]),
        .library(name: "PlutoData", targets: ["PlutoData"]),
        .library(name: "PlutoBridge", targets: ["PlutoBridge"]),
        .library(name: "PlutoWebView", targets: ["PlutoWebView"]),
        .library(name: "PlutoPresentation", targets: ["PlutoPresentation"]),
    ],
    targets: [
        .target(name: "PlutoDomain"),
        .target(name: "PlutoData", dependencies: ["PlutoDomain"]),
        .target(name: "PlutoBridge", exclude: ["bridge-schema.json"]),
        .target(name: "PlutoWebView", dependencies: ["PlutoDomain", "PlutoBridge"]),
        .target(name: "PlutoPresentation", dependencies: ["PlutoDomain", "PlutoWebView"]),
        .testTarget(name: "PlutoDataTests", dependencies: ["PlutoData", "PlutoDomain"]),
        .testTarget(name: "PlutoBridgeTests", dependencies: ["PlutoBridge"], exclude: ["bridge.vectors.json"]),
        .testTarget(name: "PlutoWebViewTests", dependencies: ["PlutoWebView", "PlutoDomain", "PlutoBridge", "PlutoData"]),
        .testTarget(name: "PlutoPresentationTests", dependencies: ["PlutoPresentation", "PlutoWebView", "PlutoDomain", "PlutoBridge", "PlutoData"]),
    ]
)
