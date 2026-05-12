//
//  PackageExtractor.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Protocol for language-specific package manifest extractors.
public protocol PackageExtractor: Sendable {
    /// Whether this extractor can handle the project at the given path.
    func canExtract(from projectPath: URL) -> Bool

    /// Extract package manifest facts from the project.
    func extract(from projectPath: URL) async throws -> PackageManifestFacts
}
