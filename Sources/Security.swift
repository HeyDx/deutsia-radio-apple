import Foundation
import CommonCrypto
func derivePIN(_ pin: String, salt: String) -> String {
    let password = Array(pin.utf8), saltBytes = Array(salt.utf8)
    var out = [UInt8](repeating: 0, count: 32)
    let status = password.withUnsafeBytes { p in saltBytes.withUnsafeBytes { s in
        CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), p.baseAddress!.assumingMemoryBound(to: Int8.self), password.count, s.baseAddress!.assumingMemoryBound(to: UInt8.self), saltBytes.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 200_000, &out, out.count)
    }}
    return status == kCCSuccess ? Data(out).base64EncodedString() : ""
}
