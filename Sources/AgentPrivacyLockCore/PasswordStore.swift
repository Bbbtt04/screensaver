import Foundation

public struct PasswordStore: Sendable {
    public static let defaultUnlockPassword = "123456"

    public let directory: URL

    public init(directory: URL = Self.defaultDirectory) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agent-privacy-lock", isDirectory: true)
    }

    public var passwordFile: URL {
        directory.appendingPathComponent("password.record")
    }

    public var hasPassword: Bool {
        FileManager.default.fileExists(atPath: passwordFile.path)
    }

    @discardableResult
    public func saveNewPassword(_ password: String) throws -> PasswordRecord {
        let record = try PasswordRecord.create(password: password)
        try save(record)
        return record
    }

    @discardableResult
    public func ensurePasswordExists() throws -> PasswordRecord {
        if hasPassword {
            return try load()
        }
        return try saveNewPassword(Self.defaultUnlockPassword)
    }

    public func isUsingDefaultPassword() throws -> Bool {
        guard hasPassword else {
            return false
        }
        return try load().verify(Self.defaultUnlockPassword)
    }

    public func save(_ record: PasswordRecord) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try record.encoded().write(to: passwordFile, atomically: true, encoding: .utf8)
    }

    public func load() throws -> PasswordRecord {
        let encoded = try String(contentsOf: passwordFile, encoding: .utf8)
        return try PasswordRecord.decode(encoded.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
