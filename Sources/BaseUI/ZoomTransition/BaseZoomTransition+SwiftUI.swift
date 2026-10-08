#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public extension View {
    /// Presents `content` full screen, zooming it out of this view. Dragging it down or right (see
    /// `configuration.dismissGestures`) shrinks it back in; so does setting `isPresented` to `false`.
    ///
    ///     CardView(card)
    ///         .baseZoomPresentation(isPresented: $showDetail, configuration: config) {
    ///             DetailView(card: card, close: { showDetail = false })
    ///         }
    ///
    /// SwiftUI shapes don't expose their corner radius: set `configuration.sourceCornerRadius` to match
    /// the view's clip shape.
    func baseZoomPresentation<Presented: View>(isPresented: Binding<Bool>,
                                               configuration: BaseZoomConfiguration = BaseZoomConfiguration(),
                                               @ViewBuilder content: @escaping () -> Presented) -> some View {
        modifier(BaseZoomPresentationModifier(isPresented: isPresented, configuration: configuration,
                                              presented: content))
    }
}

private struct BaseZoomPresentationModifier<Presented: View>: ViewModifier {
    @Binding var isPresented: Bool
    let configuration: BaseZoomConfiguration
    let presented: () -> Presented
    /// The zoomed view stands in for the source from the start of presenting to the end of dismissing.
    @State private var isSourceHidden = false

    func body(content: Content) -> some View {
        content
            .opacity(isSourceHidden ? 0 : 1)
            .background(
                BaseZoomSourceAnchor(isPresented: $isPresented, isSourceHidden: $isSourceHidden,
                                     configuration: configuration, makeContent: { AnyView(presented()) })
            )
    }
}

/// An empty view behind the source: gives UIKit the source's frame and presents from the screen on top.
private struct BaseZoomSourceAnchor: UIViewRepresentable {
    @Binding var isPresented: Bool
    @Binding var isSourceHidden: Bool
    let configuration: BaseZoomConfiguration
    let makeContent: () -> AnyView

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ anchor: UIView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if isPresented, coordinator.presented == nil {
            // Not during the view update: presenting can trigger further SwiftUI updates.
            DispatchQueue.main.async { coordinator.present(from: anchor) }
        } else if !isPresented, let presented = coordinator.presented, !presented.isBeingDismissed {
            presented.dismiss(animated: true)
        }
    }

    @MainActor
    final class Coordinator {
        var parent: BaseZoomSourceAnchor?
        weak var presented: UIViewController?

        func present(from anchor: UIView) {
            guard let parent, parent.isPresented, presented == nil,
                  let presenter = anchor.window?.rootViewController?.baseZoomTopmost else { return }
            let host = UIHostingController(rootView: parent.makeContent())
            let transition = BaseZoomTransition(source: anchor, configuration: parent.configuration)
            transition.setSourceHidden = { [weak self] hidden in self?.parent?.isSourceHidden = hidden }
            transition.onDismissed = { [weak self] in
                self?.presented = nil
                if self?.parent?.isPresented == true { self?.parent?.isPresented = false }
            }
            transition.attach(to: host)
            presented = host
            presenter.present(host, animated: true)
        }
    }
}

private extension UIViewController {
    /// The view controller currently on screen at the top of the presentation chain.
    var baseZoomTopmost: UIViewController {
        var top = self
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }
}
#endif
