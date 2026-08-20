// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PdfSplitter",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "PdfSplitter",
            targets: ["PdfSplitter"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PdfSplitter",
            path: "Sources"
        )
    ]
)
