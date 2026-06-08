//
//  Enums.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Target audience for the generated narrative.
public enum Audience: String, Codable, Sendable {
    case hiringManager
    case openSourceContributor
    case client
    case selfReflection
}

/// Style of the generated narrative.
public enum NarrativeStyle: String, Codable, Sendable {
    case caseStudy
    case projectCard
    case deepDive
}

/// Output format for rendered artifacts.
public enum OutputFormat: String, Codable, Sendable {
    case markdown // LIVE: decoded from project metadata
    case html // LIVE: decoded from project metadata
    case json // LIVE: decoded from project metadata
}

/// Detected primary language of a project.
public enum ProjectLanguage: String, Codable, Sendable {
    case swift
    case typescript // LIVE: decoded from package manifests
    case javascript
    case python
    case rust
    case go // LIVE: decoded from package manifests
    case java // LIVE: decoded from package manifests
    case kotlin // LIVE: decoded from package manifests
    case csharp // LIVE: decoded from package manifests
    case ruby // LIVE: decoded from package manifests
    case unknown // LIVE: decoded from package manifests
}
