# Aero Browser for iOS

Aero is a premium, minimalist iOS browser built with SwiftUI and WebKit. It features a clean, native design language with glassmorphic elements, a bottom-aligned navigation system, and a suite of privacy-focused tools.

## 🚀 Key Features

- **Bottom-Aligned Smart Navigation**: A unified bottom bar combining the address bar and navigation controls for easy one-handed use.
- **Tab Management**: High-performance tab grid with snapshots, supporting up to 100 concurrent tabs.
- **Privacy First**: Integrated tracker and ad blocking using `WKContentRuleList`, plus a detailed Privacy Dashboard.
- **Productivity Suite**:
    - **Reader Mode**: Distraction-free reading with adjustable typography.
    - **Find in Page**: Native search functionality with match navigation.
    - **Download Manager**: Background download support with progress tracking.
- **Persistence**: Local history and bookmark management with searchable interfaces.
- **Clean Aesthetic**: A native iOS design language that adapts seamlessly to light and dark modes, utilizing system materials and typography.

## 🛠 Technology Stack

- **Framework**: SwiftUI (Targeting iOS 17.0+)
- **Engine**: WebKit (`WKWebView`)
- **State Management**: Modern Swift `@Observable` macro
- **Persistence**: JSON-based file storage for History and Favorites
- **Architecture**: Layered MVVM approach (UI Shell, Core Engine, ViewModels, Storage, Platform)

## 📁 Project Structure

- `Aero/Views/`: All UI components including the Browser Shell, Tab Grid, and Feature Sheets.
- `Aero/ViewModels/`: Logic coordination and state management (`BrowserViewModel`, `TabManager`).
- `Aero/Core/`: WebKit integration, Download management, and Content blocking logic.
- `Aero/Models/`: Data structures for Tabs, History, and Favorites.
- `Aero/Storage/`: Persistence layers for local data.
- `Aero/Theme/`: Design system tokens and styling utilities.

## 📦 Getting Started

### Prerequisites
- macOS with **Xcode 15.0+**
- **iOS 17.0+** (Simulator or Physical Device)

### Build Instructions
1. Open `Aero.xcodeproj` in Xcode.
2. Select an iOS 17.0+ Simulator or a connected iPhone.
3. Press `⌘R` to build and run.

## 🛡 Privacy & Security

Aero is designed with privacy in mind. It uses standard WebKit security protocols and local content blocking rules to prevent tracking. No browsing data is ever synced or sent to external servers by the browser itself.

---
*Created with ❤️ by Shreyanshu*
