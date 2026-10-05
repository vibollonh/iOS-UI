import SwiftUI
import BaseUI

struct IslandToastDemoView: View {
    @State private var customText = "Payment received"
    @State private var customStyle: StyleOption = .success
    @State private var duration: Double = 2.5

    @State private var showSheet = false
    @State private var showAlert = false
    @State private var bindingToast: IslandToastMessage?

    @State private var hidesStatusBar = IslandToast.configuration.hidesStatusBarOnIsland
    @State private var tapToDismiss = IslandToast.configuration.tapToDismiss
    @State private var isFullWidth = IslandToast.configuration.isFullWidth

    var body: some View {
        Form {
            Section("Presets") {
                ForEach(StyleOption.allCases) { option in
                    Button {
                        IslandToast.show(option.sampleMessage, style: option.style)
                    } label: {
                        Label(option.title, systemImage: option.icon)
                    }
                }
            }

            Section("Custom") {
                TextField("Message", text: $customText)
                Picker("Style", selection: $customStyle) {
                    ForEach(StyleOption.allCases) { Text($0.title).tag($0) }
                }
                VStack(alignment: .leading) {
                    Text("Duration: \(duration, specifier: "%.1f")s")
                    Slider(value: $duration, in: 1...6, step: 0.5)
                }
                Button("Show custom toast") {
                    IslandToast.show(customText, style: customStyle.style, duration: duration)
                }
            }

            Section("Scenarios") {
                Button("Queue 3 toasts") {
                    IslandToast.show("Step 1: Verifying", style: .info)
                    IslandToast.show("Step 2: Sending", style: .info)
                    IslandToast.show("Step 3: Done", style: .success)
                }
                Button("Long message (2 lines)") {
                    IslandToast.show("Your transfer of $1,250.00 to Sokha Chan was completed successfully.",
                                     style: .success)
                }
                Button("Khmer text") {
                    IslandToast.show("ផ្ទេរប្រាក់បានជោគជ័យ", style: .success)
                }
                Button("Korean text") {
                    IslandToast.show("이체가 완료되었습니다", style: .success)
                }
                Button("Over a sheet") { showSheet = true }
                Button("Over an alert") {
                    showAlert = true
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        IslandToast.show("Visible above the alert", style: .warning)
                    }
                }
                Button("SwiftUI binding API (.islandToast)") {
                    bindingToast = IslandToastMessage("Sent via .islandToast($binding)", style: .info)
                }
                NavigationLink("UIKit API") {
                    UIKitToastDemo()
                        .ignoresSafeArea()
                        .navigationTitle("UIKit API")
                }
                Button("Dismiss current", role: .destructive) { IslandToast.dismiss() }
                Button("Cancel all", role: .destructive) { IslandToast.cancelAll() }
            }

            Section {
                Toggle("Hide status bar on island", isOn: $hidesStatusBar)
                Toggle("Tap to dismiss", isOn: $tapToDismiss)
                Toggle("Full width", isOn: $isFullWidth)
            } header: {
                Text("Configuration")
            } footer: {
                Text("Device: \(DeviceScreen.modelIdentifier) · \(DeviceScreen.topFeature().rawValue)")
            }
        }
        .navigationTitle("Island Toast")
        .islandToast($bindingToast)
        .onChange(of: hidesStatusBar) { IslandToast.configuration.hidesStatusBarOnIsland = $0 }
        .onChange(of: tapToDismiss) { IslandToast.configuration.tapToDismiss = $0 }
        .onChange(of: isFullWidth) { IslandToast.configuration.isFullWidth = $0 }
        .sheet(isPresented: $showSheet) { SheetDemo() }
        .alert("Alert", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The toast should appear above this alert.")
        }
    }
}

// MARK: - Style options

private enum StyleOption: String, CaseIterable, Identifiable, Hashable {
    case success, error, warning, info, custom

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var icon: String { style.symbolName }

    var style: IslandToastStyle {
        switch self {
        case .success: return .success
        case .error:   return .error
        case .warning: return .warning
        case .info:    return .info
        case .custom:  return IslandToastStyle(symbolName: "star.fill", tint: .systemYellow, haptic: .light)
        }
    }

    var sampleMessage: String {
        switch self {
        case .success: return "Transfer completed"
        case .error:   return "Insufficient balance"
        case .warning: return "Session expires in 1 min"
        case .info:    return "QR code copied"
        case .custom:  return "Custom style"
        }
    }
}

// MARK: - Sheet

private struct SheetDemo: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("The toast window sits above sheets.")
                    .foregroundStyle(.secondary)
                Button("Show toast") {
                    IslandToast.show("Shown above the sheet", style: .success)
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Sheet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack { IslandToastDemoView() }
}
