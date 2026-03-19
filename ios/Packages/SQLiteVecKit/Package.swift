// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SQLiteVecKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "SQLiteVecKit",
            targets: ["SQLiteVecKit"]
        ),
    ],
    targets: [
        .target(
            name: "SQLiteVecKit",
            dependencies: ["CSQLiteVecKit"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "CSQLiteVecKit",
            publicHeadersPath: "include",
            cSettings: [
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_CORE"),
                .headerSearchPath("internal"),
                .headerSearchPath("."),
            ]
        ),
    ]
)
