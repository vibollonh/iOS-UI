import SwiftUI
import BaseUI

/// Every BaseUI feature gets one case here and one demo screen under Features/<Name>/.
enum Feature: String, CaseIterable, Identifiable, Hashable {
  case islandToast
  case baseButton
  case baseTextField
  case baseDropdownField
  case baseReorderList
  case zoomTransition
  case deviceScreen
  
  var id: String { rawValue }
  
  var title: String {
    switch self {
    case .islandToast:  return "Island Toast"
    case .baseButton:   return "Base Button"
    case .baseTextField: return "Base Text Field"
    case .baseDropdownField: return "Dropdown Field"
    case .baseReorderList: return "Reorder List"
    case .zoomTransition: return "Zoom Presentation"
    case .deviceScreen: return "Device Screen"
    }
  }
  
  var subtitle: String {
    switch self {
    case .islandToast:  return "Dynamic Island–style toast with notch fallback"
    case .baseButton:   return "Variants, sizes, loading — UIKit and SwiftUI"
    case .baseTextField: return "Title, icon, password, helper / error — UIKit and SwiftUI"
    case .baseDropdownField: return "Text-field look with a native menu — UIKit and SwiftUI"
    case .baseReorderList: return "Drag items across sections, reorder sections — table, collection list / grid"
    case .zoomTransition: return "Zoom a screen out of a card; drag down or right to dismiss — UIKit and SwiftUI"
    case .deviceScreen: return "Dynamic Island / notch detection and calibration"
    }
  }
  
  var systemImage: String {
    switch self {
    case .islandToast:  return "capsule.fill"
    case .baseButton:   return "rectangle.and.hand.point.up.left.fill"
    case .baseTextField: return "character.cursor.ibeam"
    case .baseDropdownField: return "chevron.up.chevron.down"
    case .baseReorderList: return "line.3.horizontal"
    case .zoomTransition: return "arrow.up.left.and.arrow.down.right"
    case .deviceScreen: return "iphone"
    }
  }
  
  var section: FeatureSection {
    switch self {
    case .islandToast:  return .feedback
    case .baseButton, .baseTextField, .baseDropdownField, .baseReorderList: return .controls
    case .zoomTransition: return .presentation
    case .deviceScreen: return .utilities
    }
  }
  
  @ViewBuilder
  var destination: some View {
    switch self {
    case .islandToast:  IslandToastDemoView()
    case .baseButton:   BaseButtonDemoView()
    case .baseTextField: BaseTextFieldDemoView()
    case .baseDropdownField: BaseDropdownFieldDemoView()
    case .baseReorderList: BaseReorderListDemoView()
    case .zoomTransition: BaseZoomTransitionDemoView()
    case .deviceScreen: DeviceScreenDemoView()
    }
  }
}

enum FeatureSection: String, CaseIterable {
  case controls = "Controls"
  case feedback = "Feedback"
  case presentation = "Presentation"
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
