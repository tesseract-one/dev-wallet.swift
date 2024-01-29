//
//  TestService.swift
//  Developer Wallet
//
//  Created by Yehor Popovych on 07/11/2023.
//

import Foundation
import TesseractService

class WalletTestService: TestService {
    private let model: SignerViewModel
    private let settings: TestSettingsProvider
    
    init(model: SignerViewModel, settings: TestSettingsProvider) {
        self.model = model
        self.settings = settings
    }
    
    func signTransaction(req: String) async throws -> String {
        let settings = try self.settings.load()
        
        if (req == settings.invalidator) {
            let error = "Intentional error. Because your transaction `\(req)` is set as the invalidator in DevWallet settings"
            let request = Request.testError(TestError(transaction: req, error: error))
            
            guard try await model.confirm(request: request) else {
                throw TesseractError.cancelled
            }
            throw TesseractError.weird(reason: error)
        } else {
            let signature = settings.signature
            let signed = "\(req)#\(signature)"
            let request = Request.testSign(TestSign(transaction: req, signature: signature, result: signed))
            
            guard try await model.confirm(request: request) else {
                throw TesseractError.cancelled
            }
            return signed
        }
    }
}
