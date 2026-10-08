#if canImport(UIKit)
import UIKit

/// Lets touches pass through to the app everywhere except on the toast.
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === rootViewController?.view ? nil : hit
    }
}
#endif
