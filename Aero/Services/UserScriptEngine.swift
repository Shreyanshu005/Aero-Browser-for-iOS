//
//  UserScriptEngine.swift
//  Aero
//
//  Created by Aero on 2026-05-27.
//

import Foundation
import Observation

/// Manages user-defined JavaScript scripts that can be injected into web pages.
@Observable
final class UserScriptEngine {

    // MARK: - Public State

    /// All registered user scripts.
    private(set) var scripts: [UserScriptItem] = []

    // MARK: - Private

    private let fileURL: URL

    // MARK: - Init

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documents.appendingPathComponent("aero_user_scripts.json")
        loadFromDisk()
    }

    // MARK: - Public API

    /// Adds a new user script.
    func addScript(_ script: UserScriptItem) {
        scripts.append(script)
        saveToDisk()
    }

    /// Updates an existing user script in-place.
    func updateScript(_ script: UserScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index] = script
        saveToDisk()
    }

    /// Removes a user script.
    func removeScript(_ script: UserScriptItem) {
        scripts.removeAll { $0.id == script.id }
        saveToDisk()
    }

    /// Toggles the enabled state of a user script.
    func toggleScript(_ script: UserScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index].isEnabled.toggle()
        saveToDisk()
    }

    /// Returns all enabled scripts whose match patterns apply to the given URL.
    func enabledScripts(for url: URL) -> [UserScriptItem] {
        scripts.filter { $0.isEnabled && matchesAnyPattern($0.matchPatterns, url: url) }
    }

    // MARK: - Pattern Matching

    private func matchesAnyPattern(_ patterns: [String], url: URL) -> Bool {
        let urlString = url.absoluteString
        return patterns.contains { pattern in
            // Wildcard "*://*/*" matches everything
            if pattern == "*://*/*" { return true }
            // Simple glob-to-regex: escape dots, replace * with .*
            let escaped = pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
            return urlString.range(of: "^\(escaped)$", options: .regularExpression) != nil
        }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(scripts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Aero] Failed to save user scripts: \(error)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            scripts = try JSONDecoder().decode([UserScriptItem].self, from: data)
        } catch {
            print("[Aero] Failed to load user scripts: \(error)")
        }
    }
}
