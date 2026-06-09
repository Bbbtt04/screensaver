import Foundation

public enum ClientThemeMode: Equatable, Sendable {
    case followSystem
}

public enum ClientAppearancePolicy {
    public static let themeMode: ClientThemeMode = .followSystem
    public static let windowWidth: CGFloat = 560
    public static let windowHeight: CGFloat = 520
}
