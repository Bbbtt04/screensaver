import CryptoKit
import Foundation

public struct PasswordRecord: Codable, Equatable, Sendable {
    public enum Error: Swift.Error, Equatable {
        case emptyPassword
        case invalidEncoding
    }

    public static let defaultIterations = 120_000

    public let algorithm: String
    public let iterations: Int
    public let salt: String
    public let digest: String

    public static func create(
        password: String,
        salt: String = UUID().uuidString,
        iterations: Int = Self.defaultIterations
    ) throws -> PasswordRecord {
        guard !password.isEmpty else {
            throw Error.emptyPassword
        }

        return PasswordRecord(
            algorithm: "sha256-iterated",
            iterations: max(1, iterations),
            salt: salt,
            digest: Self.digest(password: password, salt: salt, iterations: max(1, iterations))
        )
    }

    public func verify(_ password: String) -> Bool {
        guard !password.isEmpty else {
            return false
        }

        let candidate = Self.digest(password: password, salt: salt, iterations: iterations)
        return candidate == digest
    }

    public func encoded() throws -> String {
        let data = try JSONEncoder().encode(self)
        return data.base64EncodedString()
    }

    public static func decode(_ encoded: String) throws -> PasswordRecord {
        guard let data = Data(base64Encoded: encoded) else {
            throw Error.invalidEncoding
        }
        return try JSONDecoder().decode(PasswordRecord.self, from: data)
    }

    private static func digest(password: String, salt: String, iterations: Int) -> String {
        var data = Data("\(salt):\(password)".utf8)
        for _ in 0..<iterations {
            let hash = SHA256.hash(data: data)
            data = Data(hash)
        }
        return data.map { String(format: "%02x", $0) }.joined()
    }
}
