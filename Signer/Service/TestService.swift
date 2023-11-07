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
    
    func signTransation(req: String) async -> Result<String, TesseractError> {
        let settings: TestSettings
        do {
            settings = try self.settings.load()
        } catch {
            return .failure(.swift(error: error as NSError))
        }
        
        if (req == settings.invalidator) {
            let error = "Intentional error. Because your transaction `\(req)` is set as the invalidator in DevWallet settings"
            let request = Request.testError(TestError(transaction: req, error: error))
            
            return await model.confirm(request: request).flatMap {
                $0 ? .failure(.weird(reason: error)) : .failure(.cancelled)
            }
        } else {
            let signature = settings.signature
            let signed = "\(req)#\(signature)"
            let request = Request.testSign(TestSign(transaction: req, signature: signature, result: signed))
            
            return await model.confirm(request: request).flatMap {
                $0 ? .success(signed) : .failure(.cancelled)
            }
        }
    }
}
