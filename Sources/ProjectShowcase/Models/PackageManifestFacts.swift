//
//  PackageManifestFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts extracted from a project's package manifest.
public struct PackageManifestFacts: Codable, Sendable {
    /// Primary programming language of the project.
    public let language: ProjectLanguage
    /// Tools or language version specified in the manifest, if available.
    public let toolsVersion: String?
    /// List of declared dependency names.
    public let dependencies: [String]
    /// List of declared target or module names.
    public let targets: [String]
    /// List of supported platform names (e.g. macOS, iOS).
    public let platforms: [String]

    /// Creates a new PackageManifestFacts instance.
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
