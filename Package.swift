// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

var products:[Product] = [
    .executable(name: "ModelBuilder", targets: ["ModelBuilder"])
]

var targets:[Target] = [
    .executableTarget(
        name: "ModelBuilder",
        dependencies: [
            .product( name: "ArgumentParser", package: "swift-argument-parser" )
        ]
    ),
    .testTarget(
        name: "MIOCoreDataToolsTests",
        dependencies: ["ModelBuilder"]
    )
]

if ( ProcessInfo.processInfo.environment["BUILD_PLUGIN"]?.lowercased() == "true" ) == false {
    products.append( .plugin(name: "ModelBuilderPlugin", targets: ["ModelBuilderPlugin"]) )
    targets.append( .plugin(name: "ModelBuilderPlugin", capability: .buildTool(), dependencies: ["model-builder"]) )
    
#if os(Linux)
    targets.append( .binaryTarget( name: "model-builder",
                                   url: "https://github.com/miolabs/MIOCoreData/releases/download/v1.0.0/model-builder.artifactbundle.zip",
                                   checksum: "c47c3202ae4f33f4f9bd2f1e182f51cb4607e90ebb6d13e563d20bccd8a04e2b" ) )
#else
    targets.append( .binaryTarget( name: "model-builder", path: "Binaries/model-builder.artifactbundle" ) )
#endif
    
}

let package = Package(
    name: "MIOCoreDataTools",
    products: products,
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: targets
)
