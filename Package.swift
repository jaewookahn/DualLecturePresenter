// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DualLecturePresenter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DualLecturePresenter",
            targets: ["DualLecturePresenter"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DualLecturePresenter",
            path: "Sources"
        )
    ]
)
