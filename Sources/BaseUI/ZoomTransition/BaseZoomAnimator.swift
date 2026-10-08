#if canImport(UIKit)
import UIKit

/// Zooms the presented view out of (and back into) the source view.
///
/// The view rides inside a clipping view whose frame and corner radius animate between the source's
/// frame and full screen. The view itself is scaled to the clip's width (keeping its aspect ratio) and
/// pinned to its top, so it looks like the card growing into the screen. A snapshot of the source
/// cross-fades at the small end.
@MainActor
final class BaseZoomAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let transition: BaseZoomTransition
    private let isPresenting: Bool

    init(transition: BaseZoomTransition, isPresenting: Bool) {
        self.transition = transition
        self.isPresenting = isPresenting
    }

    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
        isPresenting ? transition.configuration.presentDuration : transition.configuration.dismissDuration
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        isPresenting ? present(context) : dismiss(context)
    }

    // MARK: Present

    private func present(_ context: UIViewControllerContextTransitioning) {
        let container = context.containerView
        guard let toView = context.view(forKey: .to), let toVC = context.viewController(forKey: .to) else {
            context.completeTransition(false); return
        }
        let final = context.finalFrame(for: toVC)
        let duration = transitionDuration(using: context)

        guard let start = transition.sourceFrame(in: container) else {
            fade(toView, in: container, frame: final, appearing: true, duration: duration, context: context)
            return
        }

        let clip = makeClip(frame: start, cornerRadius: transition.sourceCornerRadius)
        container.addSubview(clip)
        place(toView, in: clip, fullSize: final.size)
        let snapshot = transition.snapshotOverlay(in: clip)
        transition.setSourceHidden(true)

        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.86) {
            clip.frame = final
            clip.layer.cornerRadius = self.transition.presentedCornerRadius
            self.place(toView, in: clip, fullSize: final.size)
            snapshot?.frame = clip.bounds
            self.transition.presentationController?.setDimming(progress: 0)
        }
        UIView.animate(withDuration: duration * 0.35) { snapshot?.alpha = 0 }
        animator.addCompletion { _ in
            snapshot?.removeFromSuperview()
            toView.transform = .identity
            toView.frame = final
            container.addSubview(toView)
            clip.removeFromSuperview()
            let finished = !context.transitionWasCancelled
            if finished { self.transition.didPresent(toView) } else { self.transition.setSourceHidden(false) }
            context.completeTransition(finished)
        }
        animator.startAnimation()
    }

    // MARK: Dismiss

    private func dismiss(_ context: UIViewControllerContextTransitioning) {
        let container = context.containerView
        guard let fromView = context.view(forKey: .from) else { context.completeTransition(false); return }
        let duration = transitionDuration(using: context)
        let fullSize = fromView.bounds.size

        // Start from where a drag left the view: its transformed frame and corner radius.
        let wasDragged = fromView.transform != .identity
        let current = fromView.frame
        let startScale = current.width / max(fullSize.width, 1)
        let startRadius = (wasDragged ? fromView.layer.cornerRadius : transition.presentedCornerRadius) * startScale

        guard let target = transition.sourceFrame(in: container) else {
            fade(fromView, in: container, frame: current, appearing: false, duration: duration, context: context)
            return
        }

        let clip = makeClip(frame: current, cornerRadius: startRadius)
        container.addSubview(clip)
        fromView.layer.cornerRadius = 0
        fromView.layer.masksToBounds = false
        place(fromView, in: clip, fullSize: fullSize)
        let snapshot = transition.snapshotOverlay(in: clip)
        snapshot?.alpha = 0

        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.9) {
            clip.frame = target
            clip.layer.cornerRadius = self.transition.sourceCornerRadius
            self.place(fromView, in: clip, fullSize: fullSize)
            snapshot?.frame = clip.bounds
            self.transition.presentationController?.setDimming(progress: 1)
        }
        UIView.animate(withDuration: duration * 0.4, delay: duration * 0.45) { snapshot?.alpha = 1 }
        animator.addCompletion { _ in
            let finished = !context.transitionWasCancelled
            if finished {
                clip.removeFromSuperview()
                self.transition.didDismiss()
            } else {
                fromView.transform = .identity
                fromView.frame = container.bounds
                container.addSubview(fromView)
                clip.removeFromSuperview()
            }
            context.completeTransition(finished)
        }
        animator.startAnimation()
    }

    // MARK: Helpers

    private func makeClip(frame: CGRect, cornerRadius: CGFloat) -> UIView {
        let clip = UIView(frame: frame)
        clip.clipsToBounds = true
        clip.autoresizesSubviews = false   // the view keeps its full size; we scale it instead
        clip.layer.cornerRadius = cornerRadius
        clip.layer.cornerCurve = .continuous
        return clip
    }

    /// Scales `view` (full-screen sized) to the clip's width and pins it to the clip's top.
    private func place(_ view: UIView, in clip: UIView, fullSize: CGSize) {
        if view.superview !== clip {
            view.transform = .identity
            view.bounds = CGRect(origin: .zero, size: fullSize)
            clip.addSubview(view)
        }
        let scale = clip.bounds.width / max(fullSize.width, 1)
        view.transform = CGAffineTransform(scaleX: scale, y: scale)
        view.center = CGPoint(x: clip.bounds.width / 2, y: fullSize.height * scale / 2)
    }

    /// No visible source: a plain fade and slight scale.
    private func fade(_ view: UIView, in container: UIView, frame: CGRect, appearing: Bool,
                      duration: TimeInterval, context: UIViewControllerContextTransitioning) {
        if appearing {
            view.frame = frame
            container.addSubview(view)
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
        UIView.animate(withDuration: duration * 0.7, animations: {
            self.transition.presentationController?.setDimming(progress: appearing ? 0 : 1)
            view.alpha = appearing ? 1 : 0
            view.transform = appearing ? .identity : view.transform.scaledBy(x: 0.9, y: 0.9)
        }, completion: { _ in
            let finished = !context.transitionWasCancelled
            if appearing, finished { self.transition.didPresent(view) }
            if !appearing, finished { self.transition.didDismiss() }
            context.completeTransition(finished)
        })
    }
}
#endif
