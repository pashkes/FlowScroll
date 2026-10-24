// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlowScroll",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FlowScroll", targets: ["FlowScroll"])],
    targets: [
        .executableTarget(name: "FlowScroll")
    ]
)
