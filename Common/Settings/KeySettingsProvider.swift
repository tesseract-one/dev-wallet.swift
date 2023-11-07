//
//  KeySettingsProvider.swift
//  Developer Wallet
//
//  Created by Daniel Leping on 15/02/2023.
//

import Foundation

protocol KeySettingsProvider {
    func load() throws -> KeySettings
    func save(settings: KeySettings) throws
}

private let KEY_SETTINGS_KEY = "KEY_SETTINGS"

extension SettingsProvider: KeySettingsProvider {
    func load() throws -> KeySettings {
        if let data = storage.data(forKey: KEY_SETTINGS_KEY) {
            return try JSONDecoder().decode(KeySettings.self, from: data)
        }
        let settings = KeySettings(mnemonic: "")
        try save(settings: settings)
        return settings
    }
    
    func save(settings: KeySettings) throws {
        let data = try JSONEncoder().encode(settings)
        storage.set(data, forKey: KEY_SETTINGS_KEY)
    }
}
