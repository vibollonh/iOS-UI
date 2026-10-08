#if canImport(UIKit)
import UIKit

/// What sits at the top of the iPhone screen.
public enum TopScreenFeature: String, Sendable {
    case dynamicIsland
    case notch
    case none
}

public enum DeviceScreen {

    /// Hardware identifier, e.g. "iPhone17,1". Returns the simulated device on the Simulator.
    public static var modelIdentifier: String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return sim
        }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    static let dynamicIslandModels: Set<String> = [
        "iPhone15,2", "iPhone15,3",   // 14 Pro, 14 Pro Max
        "iPhone15,4", "iPhone15,5",   // 15, 15 Plus
        "iPhone16,1", "iPhone16,2",   // 15 Pro, 15 Pro Max
        "iPhone17,1", "iPhone17,2",   // 16 Pro, 16 Pro Max
        "iPhone17,3", "iPhone17,4",   // 16, 16 Plus
        "iPhone18,1", "iPhone18,2",   // 17 Pro, 17 Pro Max
        "iPhone18,3", "iPhone18,4",   // 17, Air
    ]

    static let notchModels: Set<String> = [
        "iPhone10,3", "iPhone10,6",                             // X
        "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8", // XS, XS Max, XR
        "iPhone12,1", "iPhone12,3", "iPhone12,5",               // 11, 11 Pro, 11 Pro Max
        "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4", // 12 series
        "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5", // 13 series
        "iPhone14,7", "iPhone14,8",                             // 14, 14 Plus
        "iPhone17,5",                                           // 16e
    ]

    /// Pure classification (no UIKit state), so it can be unit-tested.
    ///
    /// Known identifiers win. Unknown / newer models fall back to the safe-area edge:
    /// Dynamic Island phones report ~59–62pt, notch phones 44–50pt, classic phones 20pt.
    public static func classify(modelIdentifier id: String, safeAreaEdge edge: CGFloat) -> TopScreenFeature {
        if dynamicIslandModels.contains(id) { return .dynamicIsland }
        if notchModels.contains(id) { return .notch }
        if edge >= 51 { return .dynamicIsland }
        if edge > 24 { return .notch }
        return .none
    }

    @MainActor
    public static func topFeature() -> TopScreenFeature {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return .none }
        let insets = safeAreaInsets
        // max() so it also works in landscape, where the island moves to the side.
        let edge = max(insets.top, insets.left, insets.right)
        return classify(modelIdentifier: modelIdentifier, safeAreaEdge: edge)
    }

    @MainActor
    public static var hasDynamicIsland: Bool { topFeature() == .dynamicIsland }

    @MainActor
    public static var safeAreaInsets: UIEdgeInsets { keyWindow?.safeAreaInsets ?? .zero }

    static let displayCornerRadii: [String: CGFloat] = [
        "iPhone10,3": 39, "iPhone10,6": 39,                         // X
        "iPhone11,2": 39, "iPhone11,4": 39, "iPhone11,6": 39,       // XS, XS Max
        "iPhone11,8": 41.5, "iPhone12,1": 41.5,                     // XR, 11
        "iPhone12,3": 39, "iPhone12,5": 39,                         // 11 Pro, 11 Pro Max
        "iPhone13,1": 44, "iPhone14,4": 44,                         // 12 mini, 13 mini
        "iPhone13,2": 47.33, "iPhone13,3": 47.33,                   // 12, 12 Pro
        "iPhone14,5": 47.33, "iPhone14,2": 47.33,                   // 13, 13 Pro
        "iPhone14,7": 47.33, "iPhone17,5": 47.33,                   // 14, 16e
        "iPhone13,4": 53.33, "iPhone14,3": 53.33, "iPhone14,8": 53.33, // 12/13 Pro Max, 14 Plus
        "iPhone15,2": 55, "iPhone15,3": 55,                         // 14 Pro, 14 Pro Max
        "iPhone15,4": 55, "iPhone15,5": 55,                         // 15, 15 Plus
        "iPhone16,1": 55, "iPhone16,2": 55,                         // 15 Pro, 15 Pro Max
        "iPhone17,3": 55, "iPhone17,4": 55,                         // 16, 16 Plus
        "iPhone17,1": 62, "iPhone17,2": 62,                         // 16 Pro, 16 Pro Max
        "iPhone18,1": 62, "iPhone18,2": 62,                         // 17 Pro, 17 Pro Max
        "iPhone18,3": 62, "iPhone18,4": 62,                         // 17, Air
    ]

    /// Pure lookup (no UIKit state), so it can be unit-tested.
    /// Unknown models fall back by screen type; classic phones have square corners (0).
    public static func displayCornerRadius(modelIdentifier id: String, feature: TopScreenFeature) -> CGFloat {
        if let radius = displayCornerRadii[id] { return radius }
        switch feature {
        case .dynamicIsland: return 62
        case .notch:         return 47.33
        case .none:          return 0
        }
    }

    /// Corner radius of the physical display, in points.
    @MainActor
    public static var displayCornerRadius: CGFloat {
        displayCornerRadius(modelIdentifier: modelIdentifier, feature: topFeature())
    }

    /// Approximate portrait frame of the hardware Dynamic Island, in points.
    /// Override per device with `IslandToast.configuration.islandFrame` if needed.
    public static func defaultDynamicIslandFrame(screenWidth: CGFloat) -> CGRect {
        let size = CGSize(width: 126, height: 37.33)
        return CGRect(x: (screenWidth - size.width) / 2, y: 11.33,
                      width: size.width, height: size.height)
    }

    @MainActor
    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
#endif
