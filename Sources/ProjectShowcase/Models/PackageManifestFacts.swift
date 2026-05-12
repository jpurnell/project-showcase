//
//  PackageManifestFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts extracted from a project's package manifest.
public struct PackageManifestFacts: Codable, Sendable {
    public let language: ProjectLanguage
    public let toolsVersion: String?
    public let dependencies: [String]
    public let targets: [String]
    public let platforms: [String]

    public init(
        language: ProjectLanguage,
        toolsVersion: String?,
        dependencies: [String],
        targets: [String],
        platforms: [String]
    ) {
        self.language = language
        self.toolsVersion = toolsVersion
        self.dependencies = dependencies
        self.targets = targets
        self.platforms = platforms
    }
}
