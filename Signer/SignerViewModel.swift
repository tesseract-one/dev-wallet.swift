//
//  SignerViewModel.swift
//  Signer
//
//  Created by Daniel Leping on 27/01/2023.
//

import Foundation
import TesseractService

class SignerViewModel: ObservableObject {
    private var continuation: UnsafeContinuation<Bool, Error>?
    
    @Published var request: Request?
    
    @MainActor
    func confirm(request: Request) async throws -> Bool {
        guard self.continuation == nil else {
            throw SignerError.invalidState
        }
        
        return try await withUnsafeThrowingContinuation { cont in
            self.continuation = cont
            self.request = request
        }
    }
    
    func sign() {
        self.continuation?.resume(returning: true)
        self.continuation = nil
    }
    
    func cancel() {
        self.continuation?.resume(returning: false)
        self.continuation = nil
    }
}
