//
//  SettingsProvider.swift
//  Developer Wallet
//
//  Created by Daniel Leping on 26/01/2023.
//

import Foundation

class SettingsProvider {
    public var storage: UserDefaults
    
    public init(storage: UserDefaults) {
        self.storage = storage
    }
    
    public static let shared: SettingsProvider = SettingsProvider(
        storage: .init(suiteName: "group.one.tesseract.Developer-Wallet.settings")!
    )
}
