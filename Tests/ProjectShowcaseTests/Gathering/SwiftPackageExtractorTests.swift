//
//  SwiftPackageExtractorTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

private func createFixtureProject(packageSwift: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("showcase-pkg-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try packageSwift.write(
        to: dir.appendingPathComponent("Package.swift"),
        atomically: true, encoding: .utf8
    )
    return dir
}

@Suite("SwiftPackageExtractor Tests")
struct SwiftPackageExtractorTests {

    @Test("Detects Swift language from Package.swift presence")
    func detectsSwift() async throws {
        let manifest = """
        // swift-tools-version: 5.9
        import PackageDescription
        let package = Package(name: "MyLib", targets: [.target(name: "MyLib")])
        """
        let dir = try createFixtureProject(packageSwift: manifest)
        let extractor = SwiftPackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.language == .swift)
    }

    @Test("Extracts swift-tools-version")
    func extractsToolsVersion() async throws {
        let manifest = """
        // swift-tools-version: 5.9
        import PackageDescription
        let package = Package(name: "MyLib", targets: [.target(name: "MyLib")])
        """
        let dir = try createFixtureProject(packageSwift: manifest)
        let extractor = SwiftPackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.toolsVersion == "5.9")
    }

    @Test("Extracts dependency names from package URLs")
    func extractsDependencies() async throws {
        let manifest = """
        // swift-tools-version: 5.9
        import PackageDescription
        let package = Package(
            name: "BusinessMath",
            dependencies: [
                .package(url: "https://github.com/apple/swift-numerics", from: "1.0.2"),
                .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
            ],
            targets: [.target(name: "BusinessMath")]
        )
        """
        let dir = try createFixtureProject(packageSwift: manifest)
        let extractor = SwiftPackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.dependencies.contains("swift-numerics"))
        #expect(facts.dependencies.contains("swift-collections"))
        #expect(facts.dependencies.count == 2)
    }

    @Test("Extracts target names")
    func extractsTargets() async throws {
        let manifest = """
        // swift-tools-version: 5.9
        import PackageDescription
        let package = Package(
            name: "MyLib",
            targets: [
                .target(name: "MyLib"),
                .testTarget(name: "MyLibTests"),
                .executableTarget(name: "MyCLI"),
            ]
        )
        """
        let dir = try createFixtureProject(packageSwift: manifest)
        let extractor = SwiftPackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.targets.contains("MyLib"))
        #expect(facts.targets.contains("MyLibTests"))
        #expect(facts.targets.contains("MyCLI"))
    }

    @Test("Extracts platform names")
    func extractsPlatforms() async throws {
        let manifest = """
        // swift-tools-version: 5.9
        import PackageDescription
        let package = Package(
            name: "MyLib",
            platforms: [.macOS(.v13), .iOS(.v14), .visionOS(.v1)],
            targets: [.target(name: "MyLib")]
        )
        """
        let dir = try createFixtureProject(packageSwift: manifest)
        let extractor = SwiftPackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.platforms.contains("macOS"))
        #expect(facts.platforms.contains("iOS"))
        #expect(facts.platforms.contains("visionOS"))
    }

    @Test("canExtract returns true for directory with Package.swift")
    func canExtractTrue() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-can-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let packageFile = dir.appendingPathComponent("Package.swift")
        try? "// swift-tools-version: 5.9".write(to: packageFile, atomically: true, encoding: .utf8)

        let extractor = SwiftPackageExtractor()
        #expect(extractor.canExtract(from: dir))
    }

    @Test("canExtract returns false for directory without Package.swift")
    func canExtractFalse() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-no-pkg-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let extractor = SwiftPackageExtractor()
        #expect(!extractor.canExtract(from: dir))
    }
}
