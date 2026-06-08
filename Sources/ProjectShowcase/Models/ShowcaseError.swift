//
//  ShowcaseError.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Errors that can occur during showcase operations.
public enum ShowcaseError: Error, Sendable {
    case notAGitRepository(path: String)
    case extractionFailed(source: String, message: String)
    case narrativeGenerationFailed(message: String)
    case renderingFailed(message: String) // LIVE: thrown by rendering pipeline
    case invalidConfiguration(message: String)
}
