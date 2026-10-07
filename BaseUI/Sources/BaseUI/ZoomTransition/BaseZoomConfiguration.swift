#if canImport(UIKit)
import UIKit

/// Which drags dismiss a zoom-presented view controller.
public struct BaseZoomDismissGestures: OptionSet, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Drag down: the view shrinks and follows the finger.
    public static let down = BaseZoomDismissGestures(rawValue: 1 << 0)
    /// Drag right: the view slides right and zooms out.
    public static let right = BaseZoomDismissGestures(rawValue: 1 << 1)

    public static let all: BaseZoomDismissGestures = [.down, .right]
}

/// Look and behaviour of a zoom presentation.
///
///     var config = BaseZoomConfiguration()
///     config.dismissGestures = .right
///     present(detail, zoomingFrom: cardView, configuration: config)
public struct BaseZoomConfiguration {
    /// Drags that dismiss. Empty: only code (e.g. a close button) dismisses.
    public var dismissGestures: BaseZoomDismissGestures = .all
    /// When the presented view holds a navigation stack, drags only dismiss from its first screen; pushed
    /// screens go back with the back button / edge swipe. `true` lets drag down dismiss from pushed screens
    /// too (drag right stays off there, so it can't fight the edge swipe).
    public var dismissesFromPushedScreens = false
    /// How far (points) to drag before letting go dismisses; a fast flick dismisses sooner.
    public var dismissDistance: CGFloat = 120
    /// Smallest scale the view shrinks to while dragging.
    public var minimumScale: CGFloat = 0.7
    /// Dims the presenting screen behind the zoomed view. `0` turns dimming off.
    public var dimmingAlpha: CGFloat = 0.35
    /// Corner radius of the source view. `nil` reads `source.layer.cornerRadius`.
    public var sourceCornerRadius: CGFloat?
    /// Corner radius of the full-screen view while it moves. `nil` matches the device's screen corners.
    public var presentedCornerRadius: CGFloat?
    public var presentDuration: TimeInterval = 0.5
    public var dismissDuration: TimeInterval = 0.42

    public init() {}
}
#endif
