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
    ) async -> Result<SubstrateGetAccountResponse, TesseractError> {
        await getKeyPair(type: type, path: "").asyncFlatMap { (kp, account) in
            let request = SubstrateAccount(algorithm: type.name,
                                           path: "",
                                           key: account)
            return await model.confirm(request: .substrateAccount(request)).flatMap {
                $0 ? .success(kp.pubKey) : .failure(.cancelled)
            }
        }.map { SubstrateGetAccountResponse(pubKey: $0.raw, path: "") }
    }
    
    func signTransation(
        type: SubstrateAccountType, path: String,
        extrinsic: Data, metadata: Data, types: Data
    ) async -> Result<Data, TesseractError> {
        await parseExtrinsic(
            extrinsic: extrinsic, metadata: metadata, types: types
        ).flatMap { ext in
            getKeyPair(type: type, path: path).map {
                (kp: $0.kp, ext: ext, acc: $0.acc)
            }
        }.asyncFlatMap { info in
            let ext = """
            call: \(info.ext.call)\n
            extra: \(info.ext.extra)\n
            additional: \(info.ext.add)
            """
            let request = SubstrateSign(algorithm: type.name,
                                        path: path, key: info.acc,
                                        data: ext)
            return await model.confirm(request: .substrateSign(request)).flatMap {
                $0 ? .success(info.kp) : .failure(.cancelled)
            }
        }.map { $0.sign(message: extrinsic).raw }
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
    ) -> Result<(kp: KeyPair, acc: String), TesseractError> {
        let settings: KeySettings
        do {
            settings = try self.settings.load()
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
            return try .success((kp: kp, acc: kp.pubKey.ss58(format: .substrate)))
        } catch {
            return .failure(.swift(error: error as NSError))
        }
    }
    
    func parseExtrinsic(
        extrinsic: Data, metadata: Data, types: Data
    ) -> Result<(call: Value<TypeDefinition>,
                 extra: [Value<TypeDefinition>],
                 add: [Value<TypeDefinition>]),
                TesseractError>
    {
        Result {
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
        }.mapError { .swift(error: $0 as NSError) }
    }
}
