#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// State-driven toast for SwiftUI.
///
///     @State private var toast: IslandToastMessage?
///     ...
///     .islandToast($toast)
///     ...
///     toast = IslandToastMessage("Saved", style: .success)
public struct IslandToastMessage: Identifiable, Equatable {
    public let id = UUID()
    public var text: String
    public var style: IslandToastStyle
    public var duration: TimeInterval?

    public init(_ text: String, style: IslandToastStyle = .info, duration: TimeInterval? = nil) {
        self.text = text
        self.style = style
        self.duration = duration
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

public extension View {
    /// Shows the message as an island toast, then resets the binding to `nil`.
    func islandToast(_ message: Binding<IslandToastMessage?>) -> some View {
        modifier(IslandToastModifier(message: message))
    }
}

private struct IslandToastModifier: ViewModifier {
    @Binding var message: IslandToastMessage?

    func body(content: Content) -> some View {
        content.task(id: message?.id) {
            await MainActor.run {
                guard let current = message else { return }
                IslandToast.show(current.text, style: current.style, duration: current.duration)
                message = nil
            }
        }
    }
}
#endif
