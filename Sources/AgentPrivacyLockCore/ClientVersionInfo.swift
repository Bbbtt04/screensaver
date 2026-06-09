import Foundation

public enum ClientVersionInfo {
    public static func displayName(shortVersion: String?, buildNumber: String?) -> String {
        let version = normalized(shortVersion) ?? "开发版"
        guard let build = normalized(buildNumber) else {
            return "版本 \(version)"
        }
        return "版本 \(version) (\(build))"
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
