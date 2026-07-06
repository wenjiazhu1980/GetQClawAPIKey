import Foundation

// MARK: - Crypto Errors

enum CryptoError: LocalizedError {
    case invalidBase64
    case invalidFormat
    case unsupportedFormat(String)
    case keyDerivationFailed
    case decryptionFailed
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .invalidBase64: return "无效的 Base64 编码"
        case .invalidFormat: return "密文长度不足"
        case .unsupportedFormat(let prefix): return "不支持的密文格式: \(prefix)"
        case .keyDerivationFailed: return "密钥派生失败"
        case .decryptionFailed: return "AES 解密失败"
        case .invalidUTF8: return "解密结果不是有效的 UTF-8"
        }
    }
}

// MARK: - Chromium v10 Decryption

func decryptChromiumV10(cipherText: String, password: String) throws -> String {
    guard let encrypted = Data(base64Encoded: cipherText), encrypted.count >= 3 else {
        throw CryptoError.invalidBase64
    }

    let prefix = String(data: encrypted.prefix(3), encoding: .utf8)
    guard prefix == "v10" else {
        throw CryptoError.unsupportedFormat(prefix ?? "")
    }

    let cipherData = encrypted.dropFirst(3)
    let passwordData = password.data(using: .utf8)!
    let salt = "saltysalt".data(using: .utf8)!

    // PBKDF2-SHA1, 1003 iterations, 16-byte key
    var derivedKey = Data(count: 16)
    let pbkdf2Result = derivedKey.withUnsafeMutableBytes { keyBytes in
        salt.withUnsafeBytes { saltBytes in
            passwordData.withUnsafeBytes { passBytes in
                pbkdf2_sha1_derive(
                    passBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    Int32(passwordData.count),
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    Int32(salt.count),
                    1003,
                    keyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    16
                )
            }
        }
    }

    guard pbkdf2Result == 0 else {
        throw CryptoError.keyDerivationFailed
    }

    // AES-128-CBC, IV = 16 spaces
    let iv = Data(repeating: 0x20, count: 16)
    var plainData = Data(count: cipherData.count + 16)
    var plainLen = Int32(plainData.count)

    let decryptResult = derivedKey.withUnsafeBytes { keyBytes in
        iv.withUnsafeBytes { ivBytes in
            cipherData.withUnsafeBytes { cipherBytes in
                plainData.withUnsafeMutableBytes { plainBytes in
                    aes128_cbc_decrypt(
                        keyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        Int32(derivedKey.count),
                        ivBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        Int32(iv.count),
                        cipherBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        Int32(cipherData.count),
                        plainBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        &plainLen
                    )
                }
            }
        }
    }

    guard decryptResult == 0 else {
        throw CryptoError.decryptionFailed
    }

    plainData = plainData.prefix(Int(plainLen))
    guard let result = String(data: plainData, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) else {
        throw CryptoError.invalidUTF8
    }

    return result
}