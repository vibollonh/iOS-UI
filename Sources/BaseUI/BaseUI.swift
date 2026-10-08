/// BaseUI — shared UI components.
///
/// Features:
/// - `IslandToast`   Dynamic Island–style toast (falls back to a top pill on notch / classic iPhones)
/// - `BaseButton` / `BaseButtonView`        Themed button for UIKit / SwiftUI
/// - `BaseTextField` / `BaseTextFieldView`  Themed text field for UIKit / SwiftUI
/// - `BaseDropdownField` / `BaseDropdownFieldView`  Dropdown with the text-field look for UIKit / SwiftUI
/// - `BaseReorderList` / `BaseReorderListView`      Drag items across sections and reorder sections (UITableView)
/// - `BaseReorderCollection` / `BaseReorderCollectionView`  Same, on UICollectionView with list / grid layouts
/// - `present(_:zoomingFrom:)` / `.baseZoomPresentation`  Zoom a screen out of a source view; drag down / right to dismiss
/// - `DeviceScreen`  Detects Dynamic Island / notch / classic screens
public enum BaseUI {
    public static let version = "0.1.0"
}
