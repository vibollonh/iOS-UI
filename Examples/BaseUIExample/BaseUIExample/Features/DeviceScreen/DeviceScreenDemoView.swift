import SwiftUI
import Combine
import BaseUI

struct DeviceScreenDemoView: View {
    @State private var feature: TopScreenFeature = .none
    @State private var insets: UIEdgeInsets = .zero
    @State private var showOutline = false

    var body: some View {
        List {
            Section("Detection") {
                LabeledContent("Model identifier", value: DeviceScreen.modelIdentifier)
                LabeledContent("Top feature", value: feature.rawValue)
                LabeledContent("Has Dynamic Island", value: feature == .dynamicIsland ? "Yes" : "No")
            }

            Section("Safe area (key window)") {
                LabeledContent("Top", value: format(insets.top))
                LabeledContent("Left", value: format(insets.left))
                LabeledContent("Bottom", value: format(insets.bottom))
                LabeledContent("Right", value: format(insets.right))
            }

            Section {
                Toggle("Outline island frame", isOn: $showOutline)
                Button("Show toast") {
                    IslandToast.show("Detected: \(feature.rawValue)", style: .info)
                }
            } header: {
                Text("Calibration")
            } footer: {
                Text("In portrait, the red outline should sit exactly on the hardware island. "
                     + "If it doesn't on some model, set IslandToast.configuration.islandFrame.")
            }
        }
        .navigationTitle("Device Screen")
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            DispatchQueue.main.async { refresh() }
        }
        .onChange(of: showOutline) { IslandOutlineWindow.setVisible($0) }
        .onDisappear {
            showOutline = false
            IslandOutlineWindow.setVisible(false)
        }
    }

    private func refresh() {
        feature = DeviceScreen.topFeature()
        insets = DeviceScreen.safeAreaInsets
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.1f pt", value)
    }
}

/// Draws a red outline where IslandToast thinks the hardware island is.
/// Lives in its own top-level window so nothing (nav bar, status bar) covers it.
@MainActor
private enum IslandOutlineWindow {
    private static var window: UIWindow?

    static func setVisible(_ visible: Bool) {
        guard visible else {
            window?.isHidden = true
            window = nil
            return
        }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }

        let overlay = UIWindow(windowScene: scene)
        overlay.windowLevel = .alert + 2
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false

        let frame = IslandToast.configuration.islandFrame
            ?? DeviceScreen.defaultDynamicIslandFrame(screenWidth: overlay.bounds.width)
        let outline = UIView(frame: frame)
        outline.layer.borderColor = UIColor.systemRed.cgColor
        outline.layer.borderWidth = 1
        outline.layer.cornerRadius = frame.height / 2
        outline.layer.cornerCurve = .continuous

        let root = UIViewController()
        root.view.backgroundColor = .clear
        root.view.addSubview(outline)
        overlay.rootViewController = root
        overlay.isHidden = false
        window = overlay
    }
}

#Preview {
    NavigationStack { DeviceScreenDemoView() }
}
