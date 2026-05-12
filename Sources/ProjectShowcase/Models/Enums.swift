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
    case markdown
    case html
    case json
}

/// Detected primary language of a project.
public enum ProjectLanguage: String, Codable, Sendable {
    case swift
    case typescript
    case javascript
    case python
    case rust
    case go
    case java
    case kotlin
    case csharp
    case ruby
    case unknown
}
