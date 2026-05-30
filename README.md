# Aero

Aero is a browser for iPhone built with SwiftUI and WebKit. It focuses on a clean interface, smooth navigation, and privacy features while keeping the experience simple and native to iOS.

The project explores modern iOS design patterns and browser architecture using Apple's frameworks.

---

## Preview

<p align="center">
  <img src="https://i.ibb.co/ntWpG1H/IMG-5122.png" width="180" />
  <img src="https://i.ibb.co/39GL6yF9/IMG-5123.png" width="180" />
  <img src="https://i.ibb.co/TBbKC9Mx/IMG-5124.png" width="180" />
</p>

## ✨ High-Performance Features

### 🧩 Intelligent Navigation
- **Bottom-Aligned Smart Bar**: A unified interaction point for URLs and search, designed for effortless one-handed use.
- **Dynamic Controls**: Haptic-enabled toolbar that adapts to your browsing state.
- **Seamless Gestures**: Native back/forward navigation gestures integrated with custom WebKit coordination.

### 🗂 Advanced Tab Management
- **Visual Grid Overview**: A high-performance tab grid with real-time snapshots.
- **Intelligent Lifecycle**: Efficient memory management supporting up to 100 concurrent tabs.
- **Native Navigation**: Standard iOS toolbar patterns for intuitive tab creation and switching.

### 🛡 Privacy & Security
- **Content Shield**: Integrated tracker and advertisement blocking powered by `WKContentRuleList`.
- **Privacy Dashboard**: Real-time insights into connection security and blocked trackers.
- **Zero-Footprint Mode**: Easily clear cookies, history, and website data with a single tap.

### 📖 Productivity & Utility
- **Optimized Reader Mode**: Distraction-free reading with configurable serif typography and adjustable font sizes.
- **Native Find-in-Page**: Fast, highlighted search within any webpage.
- **Background Download Manager**: Robust file downloading with progress tracking and persistent local storage.
- **Advanced Features**: 
  - **Biometric Private Tabs**: LocalAuthentication protected tabs.
  - **Page Profiler**: Real-time performance profiling for web pages.
  - **UserScripts**: Injected JavaScript engine for custom site logic.
  - **Offline Reading**: Save pages for offline consumption.
  - **Smart Tab Deduplication**: Automatically deduplicate identical tabs.

<p align="center">
  <img src="https://i.ibb.co/LX96bwsz/IMG-5125.png" width="180" />
  <img src="https://i.ibb.co/qMZsYK2q/IMG-5126.png" width="180" />
</p>

---

## Overview

Most mobile browsers try to fit many features into a small screen. Aero takes a simpler approach by focusing on browsing comfort, readable layouts, and easy one handed navigation.

The interface uses native iOS materials and places important controls within thumb reach so browsing feels natural on iPhone.

---

## Features

### Navigation

- Bottom address and search bar for easier one handed use
- Combined URL and search input
- Smooth back and forward gestures
- Haptic feedback for navigation actions
- Adaptive toolbar controls based on browsing state

### Tabs

- Grid based tab overview with live previews
- Support for multiple active tabs with memory management
- Simple tab switching and creation using familiar iOS patterns

### Privacy

- Built in tracker and ad blocking using `WKContentRuleList`
- Privacy information for websites and blocked trackers
- Clear browsing data, cookies, and history with one action

### Reading and Utility

- Reader mode for distraction free reading
- Adjustable typography and font size controls
- Find in page support
- Background file downloads with progress tracking

---

## Architecture

Aero uses a layered structure to keep the codebase organized and maintainable.

| Layer | Responsibility |
| :--- | :--- |
| **UI Shell** | SwiftUI views with native glassmorphic materials. |
| **Service Layer** | Domain-specific services (`SearchService`, `NavigationService`, `PrivacyService`, `FindInPageService`). |
| **Coordinator Layer** | Thin coordinators (`NavigationCoordinator`, `ScrollCoordinator`, `DownloadCoordinator`, `ThemeExtractor`). |
| **State Layer** | Centralized, main-actor isolated coordination using the Swift **@Observable** macro (`BrowserViewModel`). |
| **Data & Storage** | **SwiftData** backed persistent storage for History and Favorites with native `@Query` integration. |
| **Performance** | **WebViewPool** for recycling and suspending WKWebViews to handle hundreds of tabs efficiently. |
| **Advanced Features** | Custom services for PiP, Biometric Auth, UserScripts, DNS-over-HTTPS, and Offline Reading. |

### Technical Highlights
- **Target**: iOS 17.0+
- **Framework**: SwiftUI (100% Native)
- **Engine**: WebKit
- **Design**: Native Apple Design Language (SF Symbols, System Materials)

---

## Technical Details

- Platform: iOS 17 and later
- Framework: SwiftUI
- Browser Engine: WebKit
- Language: Swift
- Design System: SF Symbols and native iOS materials

---

## Roadmap

Planned features include:

- AI based webpage summaries
- CloudKit sync for bookmarks and history
- Support for Safari style extensions
- Improved fingerprinting protection

---

## Getting Started

### Clone the repository

```bash
git clone https://github.com/Shreyanshu005/Aero-Browser-for-iOS.git
```

### Open the project

```bash
cd Aero-Browser-for-iOS
open Aero.xcodeproj
```

### Build and run

Build and run the project using an iOS 17 simulator or device.

---

## About

Aero is an open source project focused on building a modern iOS browsing experience with SwiftUI and WebKit.

Built by Shreyanshu.
