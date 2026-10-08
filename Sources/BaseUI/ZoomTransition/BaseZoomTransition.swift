#if canImport(UIKit)
import UIKit
import ObjectiveC

public extension UIViewController {
    /// Presents `viewController` full screen, zooming it out of `source`. Dragging it down or right
    /// (see `BaseZoomConfiguration.dismissGestures`) shrinks it back into `source`; so does
    /// `dismiss(animated:)`.
    ///
    ///     present(DetailViewController(), zoomingFrom: cardView)
    @discardableResult
    func present(_ viewController: UIViewController, zoomingFrom source: UIView,
                 configuration: BaseZoomConfiguration = BaseZoomConfiguration(),
                 completion: (() -> Void)? = nil) -> BaseZoomTransition {
        let transition = BaseZoomTransition(source: source, configuration: configuration)
        transition.attach(to: viewController)
        present(viewController, animated: true, completion: completion)
        return transition
    }
}

/// Zoom presentation from a source view, with interactive drag-to-dismiss. Usually created through
/// `UIViewController.present(_:zoomingFrom:configuration:completion:)`; it stays alive as long as the
/// presented view controller.
@MainActor
public final class BaseZoomTransition: NSObject, UIViewControllerTransitioningDelegate {

    public private(set) weak var source: UIView?
    public var configuration: BaseZoomConfiguration

    /// Called after the presented view controller is gone, however it was dismissed.
    public var onDismissed: (() -> Void)?
    /// Hides / shows the source while the zoomed view stands in for it. The default sets its alpha;
    /// SwiftUI hosts override it because their content isn't the source view itself.
    public var setSourceHidden: (Bool) -> Void

    private weak var presented: UIViewController?
    weak var presentationController: BaseZoomPresentationController?
    /// Picture of the source taken before presenting; cross-fades at both ends of the zoom.
    private var sourceSnapshot: UIView?
    private var dragAxis: DragAxis?
    /// Scroll views under the finger while dismissing: held at their start, bounce off, then restored.
    private var heldScrollViews: [(view: UIScrollView, bounces: Bool)] = []

    private enum DragAxis { case down, right }

    public init(source: UIView, configuration: BaseZoomConfiguration = BaseZoomConfiguration()) {
        self.source = source
        self.configuration = configuration
        self.setSourceHidden = { [weak source] hidden in source?.alpha = hidden ? 0 : 1 }
        super.init()
    }

    /// Makes `viewController` present with this transition. It keeps the transition alive.
    public func attach(to viewController: UIViewController) {
        presented = viewController
        viewController.modalPresentationStyle = .custom
        viewController.transitioningDelegate = self
        objc_setAssociatedObject(viewController, &Self.associationKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private static var associationKey: UInt8 = 0

    // MARK: Geometry

    var sourceCornerRadius: CGFloat {
        configuration.sourceCornerRadius ?? source?.layer.cornerRadius ?? 0
    }

    var presentedCornerRadius: CGFloat {
        configuration.presentedCornerRadius ?? DeviceScreen.displayCornerRadius
    }

    /// The source's frame in `container`, or `nil` when it's gone or off screen (then the view fades).
    func sourceFrame(in container: UIView) -> CGRect? {
        guard let source, source.window != nil, source.window == container.window else { return nil }
        let frame = source.convert(source.bounds, to: container)
        return container.bounds.intersects(frame) ? frame : nil
    }

    func takeSourceSnapshot() {
        guard let source, let window = source.window else { return }
        let frame = source.convert(source.bounds, to: window)
        // A bitmap, not `snapshotView`: those mirror the window live, so at dismiss time they'd show
        // the zoomed view covering that spot instead of the source. Drawn from the window, so SwiftUI
        // content over a placeholder source is captured too.
        let image = UIGraphicsImageRenderer(bounds: frame).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill   // no stretching while the clip has another aspect ratio
        imageView.clipsToBounds = true
        sourceSnapshot = imageView
    }

    /// The source snapshot sized to fill `view`, for cross-fading.
    func snapshotOverlay(in view: UIView) -> UIView? {
        guard let snapshot = sourceSnapshot else { return nil }
        snapshot.removeFromSuperview()
        // The clip doesn't autoresize its subviews, so the animator resizes the snapshot with it.
        snapshot.frame = view.bounds
        view.addSubview(snapshot)
        return snapshot
    }

    // MARK: UIViewControllerTransitioningDelegate

    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?,
                                       source: UIViewController) -> UIPresentationController? {
        let controller = BaseZoomPresentationController(presentedViewController: presented, presenting: presenting)
        controller.dimmingAlpha = configuration.dimmingAlpha
        presentationController = controller
        return controller
    }

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        takeSourceSnapshot()
        return BaseZoomAnimator(transition: self, isPresenting: true)
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        BaseZoomAnimator(transition: self, isPresenting: false)
    }

    // MARK: Lifecycle (called by the animator)

    func didPresent(_ view: UIView) {
        guard !configuration.dismissGestures.isEmpty else { return }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    func didDismiss() {
        setSourceHidden(false)
        onDismissed?()
    }

    // MARK: Drag to dismiss

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let view = pan.view, let axis = dragAxis else { return }
        let translation = pan.translation(in: view.superview)
        let progress = dragProgress(translation, axis: axis)

        switch pan.state {
        case .began:
            for held in heldScrollViews { held.view.bounces = false }
            holdScrollViews()
        case .changed:
            holdScrollViews()
            view.transform = dragTransform(translation, axis: axis, progress: progress)
            view.layer.cornerRadius = presentedCornerRadius + 20 * progress
            view.layer.masksToBounds = true
            presentationController?.setDimming(progress: progress)

        case .ended:
            let velocity = pan.velocity(in: view.superview)
            let distance = axis == .down ? translation.y : translation.x
            let speed = axis == .down ? velocity.y : velocity.x
            if distance >= configuration.dismissDistance || (speed > 900 && distance > 20) {
                presented?.dismiss(animated: true)   // the dismiss animator starts from the dragged frame
            } else {
                springBack(view)
            }
            endDrag()

        case .cancelled, .failed:
            springBack(view)
            endDrag()

        default:
            break
        }
    }

    /// The scroll views scroll alongside the dismiss drag; keep their content still.
    private func holdScrollViews() {
        for (scrollView, _) in heldScrollViews {
            let inset = scrollView.adjustedContentInset
            scrollView.contentOffset = dragAxis == .right
                ? CGPoint(x: -inset.left, y: scrollView.contentOffset.y)
                : CGPoint(x: scrollView.contentOffset.x, y: -inset.top)
        }
    }

    private func endDrag() {
        for held in heldScrollViews { held.view.bounces = held.bounces }
        heldScrollViews = []
        dragAxis = nil
    }

    private func dragProgress(_ translation: CGPoint, axis: DragAxis) -> CGFloat {
        switch axis {
        case .down:  return min(max(translation.y, 0) / 400, 1)
        case .right: return min(max(translation.x, 0) / 300, 1)
        }
    }

    /// Down: shrinks and drifts with the finger. Right: slides right and zooms out.
    private func dragTransform(_ translation: CGPoint, axis: DragAxis, progress: CGFloat) -> CGAffineTransform {
        let scale = 1 - (1 - configuration.minimumScale) * progress
        let offset: CGPoint
        switch axis {
        case .down:  offset = CGPoint(x: translation.x * 0.6, y: max(translation.y, 0) * 0.55)
        case .right: offset = CGPoint(x: max(translation.x, 0) * 0.7, y: translation.y * 0.3)
        }
        return CGAffineTransform(translationX: offset.x, y: offset.y).scaledBy(x: scale, y: scale)
    }

    private func springBack(_ view: UIView) {
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            view.transform = .identity
            view.layer.cornerRadius = 0
            self.presentationController?.setDimming(progress: 0)
        } completion: { _ in
            if view.transform == .identity { view.layer.masksToBounds = false }
        }
    }
}

// MARK: - Gesture delegate

extension BaseZoomTransition: UIGestureRecognizerDelegate {

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
        let velocity = pan.velocity(in: view)
        let gestures = configuration.dismissGestures
        let pushed = isShowingPushedScreen
        guard !pushed || configuration.dismissesFromPushedScreens else { return false }
        // The first movement picks the axis; a drag in a direction that's off doesn't start.
        let axis: DragAxis
        if abs(velocity.x) > abs(velocity.y) {
            // On a pushed screen, dragging right is the navigation back swipe.
            guard velocity.x > 0, gestures.contains(.right), !pushed else { return false }
            axis = .right
        } else {
            guard velocity.y > 0, gestures.contains(.down) else { return false }
            axis = .down
        }
        // Leave scrolling to the scroll views under the finger until they're all at the edge we'd drag past.
        let scrollViews = scrollViews(at: pan.location(in: view), in: view)
        guard scrollViews.allSatisfy({ isAtLeadingEdge($0, axis: axis) }) else { return false }
        dragAxis = axis
        heldScrollViews = scrollViews.map { ($0, $0.bounces) }
        return true
    }

    /// Runs alongside scroll views' own pans, which would otherwise take the drag first.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other.view is UIScrollView
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        false
    }

    /// The presented screen has pushed past its first screen (UIKit `UINavigationController`, or the one
    /// behind a SwiftUI `NavigationStack`).
    private var isShowingPushedScreen: Bool {
        guard let presented, let navigation = Self.navigationController(in: presented) else { return false }
        return navigation.viewControllers.count > 1
    }

    private static func navigationController(in controller: UIViewController) -> UINavigationController? {
        if let navigation = controller as? UINavigationController { return navigation }
        for child in controller.children {
            if let navigation = navigationController(in: child) { return navigation }
        }
        return nil
    }

    /// Every scrolling-enabled scroll view under `point`, innermost first.
    private func scrollViews(at point: CGPoint, in view: UIView) -> [UIScrollView] {
        var result: [UIScrollView] = []
        var current = view.hitTest(point, with: nil)
        while let candidate = current, candidate !== view.superview {
            if let scrollView = candidate as? UIScrollView, scrollView.isScrollEnabled { result.append(scrollView) }
            current = candidate.superview
        }
        return result
    }

    private func isAtLeadingEdge(_ scrollView: UIScrollView, axis: DragAxis) -> Bool {
        let inset = scrollView.adjustedContentInset
        switch axis {
        case .down:  return scrollView.contentOffset.y <= -inset.top + 0.5
        case .right: return scrollView.contentOffset.x <= -inset.left + 0.5
        }
    }
}

// MARK: - Presentation controller

/// Keeps the presenting screen in place behind a dimming view.
final class BaseZoomPresentationController: UIPresentationController {
    var dimmingAlpha: CGFloat = 0.35
    private let dimmingView = UIView()

    override var shouldRemovePresentersView: Bool { false }

    /// The zoom animator fades the dimming in its own animations, so both share one timing curve
    /// (UIKit's "alongside" animations don't follow a custom property animator).
    override func presentationTransitionWillBegin() {
        guard let containerView else { return }
        dimmingView.backgroundColor = .black
        dimmingView.alpha = 0
        dimmingView.frame = containerView.bounds
        dimmingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.insertSubview(dimmingView, at: 0)
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        dimmingView.frame = containerView?.bounds ?? .zero
        if presentedView?.transform == .identity { presentedView?.frame = frameOfPresentedViewInContainerView }
    }

    /// 0 = fully dimmed, 1 = clear. Call inside an animation block to animate it.
    func setDimming(progress: CGFloat) {
        dimmingView.alpha = dimmingAlpha * (1 - progress)
    }
}
#endif
