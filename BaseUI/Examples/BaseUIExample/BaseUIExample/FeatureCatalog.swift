import SwiftUI
import BaseUI

/// Every BaseUI feature gets one case here and one demo screen under Features/<Name>/.
enum Feature: String, CaseIterable, Identifiable, Hashable {
  case islandToast
  case deviceScreen
  
  var id: String { rawValue }
  
  var title: String {
    switch self {
    case .islandToast:  return "Island Toast"
    case .deviceScreen: return "Device Screen"
    }
  }
  
  var subtitle: String {
    switch self {
    case .islandToast:  return "Dynamic Island–style toast with notch fallback"
    case .deviceScreen: return "Dynamic Island / notch detection and calibration"
    }
  }
  
  var systemImage: String {
    switch self {
    case .islandToast:  return "capsule.fill"
    case .deviceScreen: return "iphone"
    }
  }
  
  var section: FeatureSection {
    switch self {
    case .islandToast:  return .feedback
    case .deviceScreen: return .utilities
    }
  }
  
  @ViewBuilder
  var destination: some View {
    switch self {
    case .islandToast:  IslandToastDemoView()
    case .deviceScreen: DeviceScreenDemoView()
    }
  }
}

enum FeatureSection: String, CaseIterable {
  case feedback = "Feedback"
  case utilities = "Utilities"
}

struct FeatureCatalogView: View {
  var body: some View {
    NavigationStack {
      List {
        ForEach(FeatureSection.allCases, id: \.self) { section in
          let features = Feature.allCases.filter { $0.section == section }
          if !features.isEmpty {
            Section(section.rawValue) {
              ForEach(features) { feature in
                NavigationLink(value: feature) {
                  Label {
                    VStack(alignment: .leading, spacing: 2) {
                      Text(feature.title)
                      Text(feature.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                  } icon: {
                    Image(systemName: feature.systemImage)
                  }
                }
              }
            }
          }
        }
        
        Section {
          LabeledContent("BaseUI", value: BaseUI.version)
          LabeledContent("Device", value: DeviceScreen.modelIdentifier)
        }
      }
      .navigationTitle("BaseUI")
      .navigationDestination(for: Feature.self) { feature in
        feature.destination
      }
    }
  }
}
