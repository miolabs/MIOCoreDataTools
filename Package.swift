// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var products:[Product] = [
    .executable(name: "ModelBuilder", targets: ["ModelBuilder"])
]

var targets:[Target] = [
    .executableTarget(
        name: "ModelBuilder",
        dependencies: [
            .product( name: "ArgumentParser", package: "swift-argument-parser" ),
            .product( name: "DYXML", package: "DYXML" ),
        ]
    ),
    .testTarget(
        name: "MIOCoreDataToolsTests",
        dependencies: ["ModelBuilder"]
    )
]

products.append( .plugin(name: "ModelBuilderPlugin", targets: ["ModelBuilderPlugin"]) )
// The plugin runs the ModelBuilder executable built from source for the host (macOS or Linux),
// so no prebuilt binary has to be distributed with the package.
targets.append( .plugin(name: "ModelBuilderPlugin", capability: .buildTool(), dependencies: ["ModelBuilder"]) )

let package = Package(
    name: "MIOCoreDataTools",
    products: products,
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/davidy4ng/DYXML.git", from: "1.0.0")
    ],
    targets: targets
)
