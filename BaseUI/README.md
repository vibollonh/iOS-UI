# BaseUI

Shared iOS UI components as a Swift Package. iOS 15+, UIKit and SwiftUI.

## Features

| Feature | API | Demo screen |
| --- | --- | --- |
| Island Toast | `IslandToast.show("Saved", style: .success)` / `.islandToast($binding)` | `Features/IslandToast` |
| Base Button | `BaseButton(title:variant:size:action:)` (UIKit) / `BaseButtonView(...)`, `.buttonStyle(.base())` (SwiftUI) | `Features/BaseButton` |
| Base Text Field | `BaseTextField(title:placeholder:...)` (UIKit) / `BaseTextFieldView(_:text:...)` (SwiftUI) | `Features/BaseTextField` |
| Dropdown Field | `BaseDropdownField<Value>(title:placeholder:options:)` (UIKit) / `BaseDropdownFieldView(_:selection:options:)` (SwiftUI) | `Features/BaseDropdownField` |
| Reorder List | `BaseReorderList<Item>(sections:row:)` (UIKit) / `BaseReorderListView(sections: $sections, mode:)` (SwiftUI) | `Features/BaseReorderList` |
| Reorder Collection | `BaseReorderCollection<Item>(sections:layout:row:)` (UIKit) / `BaseReorderCollectionView(sections: $sections, layout: .grid(columns: 3))` (SwiftUI) | `Features/BaseReorderList` |
| Device Screen | `DeviceScreen.topFeature()`, `DeviceScreen.hasDynamicIsland` | `Features/DeviceScreen` |

## Install

Xcode → File → Add Package Dependencies → add this repo (or *Add Local…* for the folder), then:

```swift
import BaseUI

IslandToast.show("Transfer completed", style: .success)

if DeviceScreen.hasDynamicIsland { ... }
```

Optional global setup (e.g. at app launch):

```swift
IslandToast.configuration.font = UIFont(name: "KantumruyPro-SemiBold", size: 15) ?? .systemFont(ofSize: 15, weight: .semibold)
IslandToast.configuration.defaultDuration = 3
IslandToast.configuration.isFullWidth = false   // compact pill instead of edge-to-edge
```

### Base Button

Variants: `.primary`, `.secondary`, `.outline`, `.ghost`, `.destructive`. Sizes: `.small`, `.medium`, `.large`.

```swift
// UIKit
let pay = BaseButton(title: "Pay now", icon: UIImage(systemName: "creditcard"), size: .large) { [weak self] in
    self?.pay()
}
pay.isLoading = true

// SwiftUI
BaseButtonView("Pay now", systemImage: "creditcard", size: .large, isLoading: isPaying, isFullWidth: true) { pay() }

Button { ... } label: { CustomLabel() }
    .buttonStyle(.base(.outline))
```

### Base Text Field

Title, leading icon, password show / hide, helper text, error message (replaces the helper and turns the border red), `maxLength`.

```swift
// UIKit — keyboard / content type / delegate live on `textField`
let email = BaseTextField(title: "Email", placeholder: "you@example.com",
                          leadingIcon: UIImage(systemName: "envelope"))
email.textField.keyboardType = .emailAddress
email.onTextChange = { text in ... }
email.errorMessage = "Invalid email"   // nil clears it

// SwiftUI — standard modifiers pass through
BaseTextFieldView("Email", placeholder: "you@example.com", text: $email,
                  errorMessage: emailError, systemImage: "envelope")
    .keyboardType(.emailAddress)
```

### Dropdown Field

Looks like the text field (title, icon, helper / error) and opens a native menu with a checkmark on the selection.
Works with any `Hashable` value; styled by `BaseTextFieldAppearance`.

```swift
let options = [
    BaseDropdownOption(value: Bank.aba, title: "ABA Bank", subtitle: "Savings", systemImage: "building.columns"),
    BaseDropdownOption(value: Bank.wing, title: "Wing"),
]
// Plain strings: ["Phnom Penh", "Siem Reap"].map(BaseDropdownOption.init)

// UIKit
let bank = BaseDropdownField<Bank>(title: "Account", placeholder: "Select account", options: options)
bank.onSelect = { option in ... }
bank.selectedValue = .aba
bank.errorMessage = "Required"   // nil clears it

// SwiftUI
@State private var bank: Bank?
BaseDropdownFieldView("Account", placeholder: "Select account", selection: $bank, options: options,
                      errorMessage: bank == nil ? "Required" : nil)
```

### Reorder List

Drag items within **and across** sections with the drag handles. Set the mode to `.sections` to collapse each
section into one row and drag whole sections. SwiftUI wraps the UIKit list, because `.onMove` can't move items between sections.

```swift
// UIKit
let list = BaseReorderList(sections: [
    BaseReorderSection("To do", items: todo),
    BaseReorderSection("Done", items: done),
]) { task in BaseReorderRow(title: task.name, subtitle: task.note, systemImage: "checklist") }
list.onChange = { sections in save(sections) }
list.mode = .sections                 // reorder sections
list.allowsCrossSectionMoves = false  // keep items in their section
list.canMoveItem = { !$0.isPinned }   // pin items

// SwiftUI
@State private var sections: [BaseReorderSection<Task>] = ...
@State private var mode: BaseReorderMode = .items
BaseReorderListView(sections: $sections, mode: mode) { BaseReorderRow(title: $0.name) }
```

**Collection view version:** `BaseReorderCollection` / `BaseReorderCollectionView` has the same API plus `layout: .list` or
`.grid(columns:)`. Press and hold anywhere on an item, then drag. Empty sections show a "Drag items here" drop zone.

```swift
let board = BaseReorderCollection(sections: sections, layout: .grid(columns: 3)) { app in
    BaseReorderRow(title: app.name, systemImage: app.icon)
}
board.onChange = { sections in save(sections) }

BaseReorderCollectionView(sections: $sections, mode: mode, layout: .grid(columns: 3)) { BaseReorderRow(title: $0.name) }
```

**Dragging whole sections (cells included):** in `.items` mode, press and hold a section header (it shows a ≡ handle)
to lift the entire section — header and all its cells — and drag it. Other sections make room live, the list
autoscrolls near the edges, and pinned sections stay put. Turn it off with `allowsSectionDragging = false`.
VoiceOver users get "Move section up / down" actions on headers; the same move is available in code as
`collection.moveSection(id:by:)`. The collapsed `.sections` mode is still there for long sections.

**Different cell types per section and pinned sections:** each section can set its own `layout`
(`.list`, `.grid(columns:)`, `.carousel`, `.banner`, each with its own cell). `isPinned: true` keeps a section in place:
it can't be dragged and other sections can't be dragged past it. `allowsItemMoves: false` also locks its items.

```swift
BaseReorderCollectionView(sections: $sections) { BaseReorderRow(title: $0.name, systemImage: $0.icon) }

sections = [
    BaseReorderSection("Sprint goal", items: [goal], layout: .banner, isPinned: true, allowsItemMoves: false),
    BaseReorderSection("Favorites", items: favorites, layout: .carousel),
    BaseReorderSection("To do", items: todo, layout: .list),
    BaseReorderSection("Done", items: done, layout: .grid(columns: 3)),
]
```

The table-based `BaseReorderList` honors `isPinned` and `allowsItemMoves` too (it ignores `layout`).

**Cell width / height:** set `itemSize` on a section, or on the collection as the default for all sections.
Each dimension is `.automatic`, `.absolute(pt)`, `.fractionalWidth(f)` (a fraction of the section's content width;
for height that gives an aspect ratio) or `.estimated(pt)` (grows to fit content).

```swift
BaseReorderSection("Favorites", items: favorites, layout: .carousel,
                   itemSize: .fixed(width: 200, height: 120))                       // fixed cards
BaseReorderSection("Featured", items: featured, layout: .carousel,
                   itemSize: .init(width: .fractionalWidth(0.8)))                   // 80% wide, auto height
BaseReorderSection("Apps", items: apps, layout: .grid(columns: 3),
                   itemSize: .init(width: .absolute(80), height: .absolute(96)))   // as many 80pt columns as fit
BaseReorderSection("Inbox", items: mail, layout: .list,
                   itemSize: .init(height: .absolute(72)))                          // list: height only

collection.itemSize = .init(height: .estimated(100))   // default for sections without their own
```

**Per-item size:** give individual cells their own size with `sizeForItem` (dimensions left `.automatic`
fall back to the section's `itemSize`):

```swift
collection.sizeForItem = { item, section in
    item.isFeatured ? .init(width: .absolute(260)) : nil
}
// SwiftUI: BaseReorderCollectionView(sections: $s, sizeForItem: { item, section in … }) { … }
```

**Section height:** `BaseReorderSection(…, height: 180)` fixes the height of a section's cell area. Carousel and
banner cells with an automatic height fill it; grid cells that don't fit continue on pages that scroll sideways.
`.list` sections ignore it (use `itemSize` row heights instead). Sections using `sizeForItem` or `height` are laid
out with exact frames, so `.estimated` sizes act as fixed in them.

Width per layout: grid — `.absolute` fits as many columns of that width as possible (spare space goes between
them) and `.fractionalWidth(0.25)` means 4 columns; carousel / banner — the cell width; list — ignored.

Both lists fill their frame and scroll themselves, so don't put them inside a scroll view. The move logic is also available
on its own as `BaseReorder.moveItem(in:from:to:)` / `BaseReorder.moveSection(in:from:to:)`.

### Theming

Both components share one theme between UIKit and SwiftUI:

```swift
BaseButtonAppearance.shared.tintColor = UIColor(named: "Brand")!
BaseButtonAppearance.shared.font = UIFont(name: "KantumruyPro-SemiBold", size: 16)!
BaseButtonAppearance.shared.cornerRadius = nil   // capsule

BaseTextFieldAppearance.shared.focusedBorderColor = UIColor(named: "Brand")!
BaseTextFieldAppearance.shared.font = UIFont(name: "KantumruyPro-Regular", size: 16)!
```

Set these at launch, before any views are created. To give one control its own look, pass an `appearance:` to it.

## Sample app

Open `Examples/BaseUIExample/BaseUIExample.xcodeproj` and run the **BaseUIExample** scheme on a simulator or device.
It links this package locally (`../..`), so edits under `Sources/` show up on the next run.
Requires Xcode 16 or newer.

Each feature has its own demo screen, listed on the home catalog.

Tip: test the toast on an iPhone 15/16/17 simulator (Dynamic Island) **and** an iPhone 14 / 16e simulator (notch).

## Tests

UIKit-based, so run them on an iOS simulator:

```bash
xcodebuild test -scheme BaseUI -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Or open `Package.swift` in Xcode, pick an iOS simulator, and press ⌘U.

## Structure

```
BaseUI/
├── Package.swift
├── Sources/BaseUI/
│   ├── BaseUI.swift
│   ├── Device/DeviceScreen.swift
│   ├── BaseButton/              (Appearance, UIKit, +SwiftUI)
│   ├── BaseTextField/           (Appearance, UIKit, +SwiftUI)
│   ├── BaseDropdownField/       (Option, UIKit, +SwiftUI)
│   ├── BaseReorderList/         (Section + move logic; table + collection, UIKit, +SwiftUI)
│   └── IslandToast/
│       ├── IslandToast.swift
│       ├── IslandToast+SwiftUI.swift
│       ├── IslandToastStyle.swift
│       ├── IslandToastConfiguration.swift
│       └── Internal/            (overlay window plumbing)
├── Tests/BaseUITests/
└── Examples/BaseUIExample/
    ├── BaseUIExample.xcodeproj
    └── BaseUIExample/
        ├── BaseUIExampleApp.swift
        ├── FeatureCatalog.swift   ← one case per feature
        └── Features/<Feature>/    ← one demo per feature
```

## Adding a feature

1. Add the source under `Sources/BaseUI/<Feature>/`; mark the API `public`.
2. Add tests under `Tests/BaseUITests/<Feature>Tests.swift`.
3. Add a demo view under `Examples/BaseUIExample/BaseUIExample/Features/<Feature>/`.
   The project uses folder-synced groups, so new files are picked up automatically.
4. Add a case to `Feature` in `FeatureCatalog.swift` (title, subtitle, icon, section, destination).
