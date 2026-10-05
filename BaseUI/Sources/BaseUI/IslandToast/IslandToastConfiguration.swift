#if canImport(UIKit)
import UIKit

/// Global appearance / behaviour. Set once at launch:
///
///     IslandToast.configuration.font = UIFont(name: "KantumruyPro-SemiBold", size: 15)!
public struct IslandToastConfiguration {

    public var font: UIFont = .systemFont(ofSize: 15, weight: .semibold)
    public var textColor: UIColor = .white
    /// Keep black on Dynamic Island phones so the pill blends with the hardware island.
    public var backgroundColor: UIColor = .black

    /// In portrait, stretch the toast edge to edge (minus the side inset) like an expanded
    /// Dynamic Island alert. Landscape always uses the compact pill capped at `maxWidth`.
    public var isFullWidth: Bool = true
    /// Gap between the full-width toast and the screen's side edges. `nil` matches the gap
    /// above the toast on Dynamic Island phones (the island's top offset), and 10pt elsewhere.
    public var fullWidthInset: CGFloat?

    public var maxWidth: CGFloat = 360
    public var maxLines: Int = 2
    public var defaultDuration: TimeInterval = 2.5
    /// Corner radius of the expanded toast. `nil` matches the device: in full width the toast is
    /// concentric with the display corners (`displayCornerRadius` minus the side inset), otherwise 28.
    public var expandedCornerRadius: CGFloat?

    /// The expanded island covers the clock / battery, so hide the status bar meanwhile.
    public var hidesStatusBarOnIsland: Bool = true
    public var tapToDismiss: Bool = true
    public var announcesForVoiceOver: Bool = true

    /// Override the hardware island frame (portrait, points) if the default doesn't line up
    /// on a specific device. `nil` uses `DeviceScreen.defaultDynamicIslandFrame`.
    public var islandFrame: CGRect?

    public init() {}
}
#endif
