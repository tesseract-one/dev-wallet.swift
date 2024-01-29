//
//  SubstrareService.swift
//  Signer
//
//  Created by Yehor Popovych on 07/11/2023.
//

import Foundation
import TesseractService
import Bip39
import Substrate
import SubstrateKeychain
import ScaleCodec

class WalletSubstrateService: SubstrateService {
    private let model: SignerViewModel
    private let settings: KeySettingsProvider
    
    init(model: SignerViewModel, settings: KeySettingsProvider) {
        self.model = model
        self.settings = settings
    }
    
    func getAccount(
        type: SubstrateAccountType
    ) async throws -> SubstrateGetAccountResponse {
        let path = ""
        let (kp, account) = try getKeyPair(type: type, path: path)
        let request = SubstrateAccount(algorithm: type.name,
                                       path: path,
                                       key: account)
        guard try await model.confirm(request: .substrateAccount(request)) else {
            throw TesseractError.cancelled
        }
        return .init(pubKey: kp.pubKey.raw, path: path)
    }
    
    func signTransaction(
        type: SubstrateAccountType, path: String,
        extrinsic: Data, metadata: Data, types: Data
    ) async throws -> Data {
        let info = try parseExtrinsic(extrinsic: extrinsic,
                                      metadata: metadata,
                                      types: types)
        let (kp, account) = try getKeyPair(type: type, path: path)
        
        let ext = """
        call: \(info.call)\n
        extra: \(info.extra)\n
        additional: \(info.add)
        """
        let request = SubstrateSign(algorithm: type.name,
                                    path: path, key: account,
                                    data: ext)
        guard try await model.confirm(request: .substrateSign(request)) else {
            throw TesseractError.cancelled
        }
        
        return kp.sign(tx: extrinsic).raw
    }
}

extension SubstrateAccountType {
    var name: String {
        switch self {
        case .sr25519: return "Sr25519"
        case .ed25519: return "Ed25519"
        case .ecdsa: return "ECDSA"
        }
    }
}

private extension WalletSubstrateService {
    func getKeyPair(
        type: SubstrateAccountType, path: String
    ) throws -> (kp: KeyPair, acc: String) {
        let settings = try self.settings.load()
        let seed = try Mnemonic(
            mnemonic: settings.mnemonic.components(separatedBy: " ")
        ).substrate_seed()
        var kp: KeyPair & KeyDerivable
        switch type {
        case .sr25519: kp = try Sr25519KeyPair(seed: Data(seed))
        case .ed25519: kp = try Ed25519KeyPair(seed: Data(seed))
        case .ecdsa: kp = try EcdsaKeyPair(seed: Data(seed))
        }
        if path != "" {
            kp = try kp.derive(path: [PathComponent(string: path)])
        }
        return try(kp: kp, acc: kp.pubKey.ss58(format: .substrate))
    }
    
    func parseExtrinsic(
        extrinsic: Data, metadata: Data, types: Data
    ) throws -> (call: Value<TypeDefinition>,
                 extra: [Value<TypeDefinition>],
                 add: [Value<TypeDefinition>])
    {
        var typesDecoder = ScaleCodec.decoder(from: types)
        let networkRegistry = try NetworkType.Registry(from: &typesDecoder)
        let typeRegistry = try NetworkTypeRegistry.from(network: networkRegistry).get()
        
        var metaDecoder = ScaleCodec.decoder(from: metadata)
        let extMeta = try MetadataV14.Network.Extrinsic(from: &metaDecoder)
        
        var extDecoder = ScaleCodec.decoder(from: extrinsic)
        let call = try Value(from: &extDecoder, as: typeRegistry.get(extMeta.type, .get()))
        let extra = try extMeta.signedExtensions.map { ext in
            try Value(from: &extDecoder, as: typeRegistry.get(ext.type, .get()))
        }
        let add = try extMeta.signedExtensions.map { ext in
            try Value(from: &extDecoder, as: typeRegistry.get(ext.additionalSigned, .get()))
        }
        return (call: call, extra: extra, add: add)
    }
}
