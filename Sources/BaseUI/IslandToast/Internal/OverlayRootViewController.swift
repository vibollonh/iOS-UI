#if canImport(UIKit)
import UIKit

/// Mirrors the app's status bar style so the overlay window doesn't change it,
/// and hides the status bar while the expanded island covers it.
final class OverlayRootViewController: UIViewController {
    var hidesStatusBar = false

    private var appTopController: UIViewController? {
        var vc = DeviceScreen.keyWindow?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }

    override var prefersStatusBarHidden: Bool {
        hidesStatusBar || (appTopController?.prefersStatusBarHidden ?? false)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        appTopController?.preferredStatusBarStyle ?? .default
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
}
#endif
