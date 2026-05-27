# Aero: A Premium Browsing Experience for iOS

**Native. Minimalist. Secure.**

Aero is a state-of-the-art iOS browser built from the ground up using **SwiftUI** and **WebKit**. It redefines the mobile browsing experience by combining a sleek, glassmorphic design language with advanced navigation features and robust privacy protection.

---

## 🌟 The Aero Vision

In a world of cluttered browsers, Aero focuses on what matters most: your content. By moving navigation to the bottom and utilizing native iOS system materials, Aero provides a distraction-free environment that feels like a natural extension of iOS.

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

---

## 🛠 Engineering & Architecture

Aero follows a modern, layered architecture to ensure scalability and performance.

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

## 📂 Project Roadmap

- [ ] **AI Summarization**: Intelligent webpage summaries using local models.
- [ ] **CloudKit Sync**: Securely sync bookmarks and history across devices.
- [ ] **Extension Support**: Native Safari-compatible extension bridge.
- [ ] **Advanced Fingerprinting Protection**: Enhanced privacy layers for anonymous browsing.

## 📦 Build & Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Shreyanshu005/Aero-Browser-for-iOS.git
   ```
2. **Open the project**:
   Navigate to the directory and open `Aero.xcodeproj`.
3. **Build**:
   Select an iOS 17.0+ device/simulator and press `⌘R`.

---

*Aero is an open-source exploration of premium mobile interface design and modern Swift technologies.*

**Designed and Built by [Shreyanshu](https://github.com/Shreyanshu005)**
