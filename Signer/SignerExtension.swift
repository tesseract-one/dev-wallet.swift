//
//  SignerExtension.swift
//  Signer
//
//  Created by Daniel Leping on 27/01/2023.
//

import SwiftUI
import TesseractService

class SignerExtension: UIExtension {
    private let tesseract: Tesseract
    private var model: SignerViewModel
    
    required init(controller: UIViewController) {
        let model = SignerViewModel()
        let settings = SettingsProvider.shared
        
        let testService = WalletTestService(model: model, settings: settings)
        let substrateService = WalletSubstrateService(model: model, settings: settings)

        let tesseract = try! Tesseract()
            .transport(IPCTransportIOS(controller))
            .service(testService)
            .service(substrateService)
        
        self.model = model
        self.tesseract = tesseract
    }
    
    var body: some View {
        SignerView(model: self.model)
    }
}
