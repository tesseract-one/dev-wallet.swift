//
//  TestSettingsProvider.swift
//  Developer Wallet
//
//  Created by Daniel Leping on 26/01/2023.
//

import Foundation

protocol TestSettingsProvider {
    func load() throws -> TestSettings
    func save(settings: TestSettings) throws
}

private let TEST_SETTINGS_KEY = "TEST_SETTINGS"

extension SettingsProvider: TestSettingsProvider {
    func load() throws -> TestSettings {
        if let data = storage.data(forKey: TEST_SETTINGS_KEY) {
            return try JSONDecoder().decode(TestSettings.self, from: data)
        }
        let settings = TestSettings(signature: "_signed", invalidator: "_error")
        try save(settings: settings)
        return settings
    }
    
    func save(settings: TestSettings) throws {
        let data = try JSONEncoder().encode(settings)
        storage.set(data, forKey: TEST_SETTINGS_KEY)
    }
}
