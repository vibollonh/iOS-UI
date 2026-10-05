# BaseUI

Shared iOS UI components as a Swift Package. iOS 15+, UIKit and SwiftUI.

## Features

| Feature | API | Demo screen |
| --- | --- | --- |
| Island Toast | `IslandToast.show("Saved", style: .success)` / `.islandToast($binding)` | `Features/IslandToast` |
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
