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

extension SubstrateAccountType {
    public var name: String {
        switch self {
        case .sr25519: return "Sr25519"
        case .ed25519: return "Ed25519"
        case .ecdsa: return "ECDSA"
        }
    }
}

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
        await getKeyPair(type: type)
            .flatMap { kp in
                Result { try kp.pubKey.ss58(format: .substrate) }
                    .mapError { .swift(error: $0 as NSError) }
                    .map { (kp, $0) }
            }
            .asyncFlatMap { (kp, account) in
                let request = SubstrateAccount(algorithm: type.name,
                                               path: "",
                                               key: account)
                return await model.confirm(request: .substrateAccount(request)).map {
                    $0 ? kp.pubKey : nil
                }
            }
            .flatMap { (pubKey: (any PublicKey)?) in
                guard let pubKey = pubKey else { return .failure(.cancelled) }
                return .success(SubstrateGetAccountResponse(pubKey: pubKey.raw, path: ""))
            }
    }
    
    func signTransation(
        type: SubstrateAccountType, path: String,
        extrinsic: Data, metadata: Data, types: Data
    ) async -> Result<Data, TesseractError> {
        await parseExtrinsic(extrinsic: extrinsic, metadata: metadata, types: types).flatMap { ext in
            getKeyPair(type: type).flatMap { kp in
                Result { try kp.pubKey.ss58(format: .substrate) }
                    .mapError { .swift(error: $0 as NSError) }
                    .map { (kp: kp, ext: ext, acc: $0) }
            }
        }.asyncFlatMap { info in
            let ext = """
            call: \(info.ext.call)\n
            extra: \(info.ext.extra)\n
            additional: \(info.ext.add)
            """
            let request = SubstrateSign(algorithm: type.name,
                                        path: "", key: info.acc,
                                        data: ext)
            return await model.confirm(request: .substrateSign(request)).map {
                $0 ? info.kp : nil
            }
        }.flatMap { (kp: (any KeyPair)?) in
            kp.map { .success($0.sign(message: extrinsic).raw) } ?? .failure(.cancelled)
        }
    }
    
    private func getKeyPair(type: SubstrateAccountType) -> Result<KeyPair, TesseractError> {
        let settings: KeySettings
        do {
            settings = try self.settings.load()
            let seed = try Data(Mnemonic(
                mnemonic: settings.mnemonic.components(separatedBy: " ")
            ).substrate_seed())
            switch type {
            case .sr25519: return try .success(Sr25519KeyPair(seed: seed))
            case .ed25519: return try .success(Ed25519KeyPair(seed: seed))
            case .ecdsa: return try .success(EcdsaKeyPair(seed: seed))
            }
        } catch {
            return .failure(.swift(error: error as NSError))
        }
    }
    
    private func parseExtrinsic(
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
