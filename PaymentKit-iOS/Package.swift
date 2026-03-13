// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaymentKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PaymentKit",
            targets: ["PaymentKit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/SDWebImage/SDWebImage.git",
            from: "5.0.0"
        )
    ],
    targets: [
        .target(
            name: "PaymentKit",
            dependencies: ["SDWebImage"],
            path: "PaymentKit"        // ← 여기 변경
        ),
        .testTarget(
            name: "PaymentKitTests",
            dependencies: ["PaymentKit"],
            path: "PaymentKit-iOSTests"  // ← 여기 변경
        )
    ]
)
