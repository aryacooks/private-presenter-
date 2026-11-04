// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrivatePresenter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PrivatePresenter", targets: ["PrivatePresenter"])
    ],
    targets: [
        .executableTarget(
            name: "PrivatePresenter",
            path: "Sources/PrivatePresenter"
        ),
        .testTarget(name: "PrivatePresenterTests", dependencies: ["PrivatePresenter"])
    ]
)
