//
//  InfographicGenerator.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// A generator that produces an SVG infographic from a ``ProjectCard``.
public protocol InfographicGenerator: Sendable {
    /// Generate an SVG string from the given project card.
    /// - Parameter card: The project card containing gathered facts.
    /// - Returns: A string containing valid SVG markup.
    func generate(from card: ProjectCard) throws -> String
}
