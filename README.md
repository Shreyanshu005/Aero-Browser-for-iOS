# Aero

Aero is a browser for iPhone built with SwiftUI and WebKit. It focuses on a clean interface, smooth navigation, and privacy features while keeping the experience simple and native to iOS.

The project explores modern iOS design patterns and browser architecture using Apple's frameworks.

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
| --- | --- |
| UI | SwiftUI based interface using native system materials |
| Browser Engine | WebKit integration and navigation coordination |
| State Management | Shared app state using Swift `@Observable` |
| Storage | JSON based persistence for history and bookmarks |
| Privacy | Content blocking and tracker filtering |

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
