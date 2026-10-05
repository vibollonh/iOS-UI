#if canImport(UIKit)
import UIKit

/// Icon, tint and haptic for a toast. Use a preset or build your own.
///
///     let brand = IslandToastStyle(symbolName: "star.fill", tint: .systemYellow, haptic: .light)
public struct IslandToastStyle {

    public enum Haptic {
        case success, warning, error, light, none
    }

    public var symbolName: String
    public var tint: UIColor
    public var haptic: Haptic

    public init(symbolName: String, tint: UIColor, haptic: Haptic = .light) {
        self.symbolName = symbolName
        self.tint = tint
        self.haptic = haptic
    }

    public static var success: IslandToastStyle {
        .init(symbolName: "checkmark.circle.fill",
              tint: UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1),
              haptic: .success)
    }

    public static var error: IslandToastStyle {
        .init(symbolName: "xmark.octagon.fill",
              tint: UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1),
              haptic: .error)
    }

    public static var warning: IslandToastStyle {
        .init(symbolName: "exclamationmark.triangle.fill",
              tint: UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1),
              haptic: .warning)
    }

    public static var info: IslandToastStyle {
        .init(symbolName: "info.circle.fill",
              tint: UIColor(red: 0.04, green: 0.52, blue: 1.00, alpha: 1),
              haptic: .light)
    }

    @MainActor
    func playHaptic() {
        switch haptic {
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:   UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .light:   UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .none:    break
        }
    }
}
#endif
