# 🚗 NoOneLeftBehind — Convoy Travel Companion

<p align="center">
  <img src="assets/images/logo_square.png" width="150" alt="NoOneLeftBehind Logo"/>
</p>

<p align="center">
  <strong>Stay connected. Stay together. No one gets left behind.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/Firebase-RTDB-FFCA28?logo=firebase" alt="Firebase"/>
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android" alt="Android"/>
</p>

---

## 📖 About

**NoOneLeftBehind** is a real-time convoy tracking app built for group road trips. Whether you're on a family caravan, a bike rally, or a multi-vehicle road trip, this app ensures every member of the convoy stays connected and no one gets separated.

A trip host creates a convoy session with a unique trip code, and members join using that code. Everyone's live location is shared on a real-time interactive map, complete with in-convoy chat, SOS alerts, halt coordination, and trip history.

---

## ✨ Features

### 🗺️ Real-Time Convoy Map
- **Live location tracking** for all convoy members on an interactive OpenStreetMap
- **Custom bobblehead markers** with member profile pictures
- **Speed display** and **destination info** in the convoy panel
- **Route polylines** showing the planned path
- **Auto-centering** and smart map controls

### 👥 Trip Management
- **Host a Trip** — Create a convoy with vehicle type, destination, and member limit
- **Join a Trip** — Enter a 6-character trip code to join an existing convoy
- **Trip Code Sharing** — Share trip codes via any app or QR-style share screen
- **Session Restore** — Automatically rejoin your last active trip on app restart
- **Trip Summary** — View distance, duration, and statistics when a trip ends

### 💬 Convoy Chat
- **Real-time group messaging** with Firebase Realtime Database
- **Voice messages** — Record and send audio clips
- **Image sharing** — Send photos via Cloudinary integration
- **System messages** for join/leave/SOS events
- **Unread message counter** with visual badges

### 🚨 SOS Emergency System
- **Shake-to-SOS** — Trigger emergency alerts by shaking your phone
- **SOS button** with countdown timer and audio alarm
- **Real-time SOS broadcasts** to all convoy members
- **SOS resolution** when the emergency is handled
- **Vibration and sound alerts** for incoming SOS notifications

### ⏸️ Halt Coordination
- **Propose a halt** for fuel stops, rest breaks, or emergencies
- **Voting system** — Members vote to approve or reject halt proposals
- **Real-time halt status** visible to all members
- **Auto-halt detection** when the lead vehicle stops

### 🌙 Dark Mode
- **Night driving theme** with carefully tuned dark colors
- **Light/Dark toggle** for readability in all conditions
- **Themed map tiles** that adapt to the current mode

### 📱 Background Tracking
- **Foreground service** keeps location updates running when the app is minimized
- **Battery-aware tracking** — Reduces GPS frequency on low battery
- **Connectivity monitoring** — Handles network drops gracefully

### 📜 Trip History
- View past trips with date, distance, duration, and member count
- **Face-cropped profile pictures** using ML Kit face detection

---

## 🏗️ Architecture

```
lib/
├── main.dart                  # App entry point & theme configuration
├── constants.dart             # Color palette & design tokens
├── firebase_options.dart      # Firebase configuration
├── auth_service.dart          # Anonymous Firebase authentication
│
├── models/                    # Data models
│   ├── trip_model.dart        # Trip session data
│   ├── member_model.dart      # Convoy member data
│   ├── chat_message_model.dart# Chat messages
│   ├── halt_model.dart        # Halt proposals
│   ├── sos_model.dart         # SOS alerts
│   └── history_model.dart     # Trip history records
│
├── providers/                 # State management (Provider)
│   ├── trip_provider.dart     # Core trip state & business logic
│   └── theme_provider.dart    # Light/dark mode
│
├── services/                  # Background services & APIs
│   ├── location_service.dart  # GPS tracking & foreground service
│   ├── trip_service.dart      # Firebase trip CRUD operations
│   ├── chat_service.dart      # Real-time messaging
│   ├── halt_service.dart      # Halt proposal management
│   ├── sos_service.dart       # Emergency alert system
│   ├── route_service.dart     # Route polyline fetching
│   ├── audio_service.dart     # Voice message recording
│   ├── battery_service.dart   # Battery level monitoring
│   ├── connectivity_service.dart # Network status
│   └── shake_detector_service.dart # Shake-to-SOS
│
├── screens/                   # UI screens
│   ├── splash_screen.dart     # Animated splash with session restore
│   ├── onboarding_screen.dart # First-time user onboarding
│   ├── permissions_onboarding_screen.dart
│   ├── lobby_screen.dart      # Host or join a trip
│   ├── host_setup_screen.dart # Configure a new trip
│   ├── join_setup_screen.dart # Enter trip code to join
│   ├── share_code_screen.dart # Share trip code
│   ├── map_screen.dart        # Main convoy map view
│   ├── chat_screen.dart       # In-convoy chat
│   ├── halt_screen.dart       # Halt voting & management
│   ├── sos_screen.dart        # SOS alert interface
│   ├── history_screen.dart    # Past trip history
│   └── face_crop_screen.dart  # Profile photo face detection
│
├── widgets/                   # Reusable components
│   ├── convoy_panel.dart      # Bottom panel with member list
│   ├── convoy_drawer.dart     # Side drawer with convoy info
│   ├── bobblehead_marker.dart # Custom map markers
│   ├── member_detail_sheet.dart # Member info bottom sheet
│   └── trip_summary_dialog.dart # End-of-trip summary
│
└── utils/                     # Utilities
    ├── navigation_utils.dart  # Navigation helpers
    └── page_transitions.dart  # Custom page transition animations
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.11+ / Dart 3.11+ |
| **State Management** | Provider |
| **Backend** | Firebase Realtime Database |
| **Authentication** | Firebase Anonymous Auth |
| **Maps** | flutter_map + OpenStreetMap tiles |
| **Location** | Geolocator + Foreground Service |
| **ML** | Google ML Kit (Face Detection, Selfie Segmentation) |
| **Media** | Cloudinary (image hosting), Audioplayers |
| **Design** | Material 3, Custom Thicccboi font family |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>= 3.11.0`
- Android Studio / VS Code
- A physical Android device (GPS required)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/RushitT713/nooneleftbehindflutterproject.git
   cd nooneleftbehindflutterproject
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Building for Release

```bash
flutter build appbundle --release
```

The signed `.aab` will be at `build/app/outputs/bundle/release/app-release.aab`.

---

## 📋 Permissions

The app requires the following Android permissions:

| Permission | Purpose |
|-----------|---------|
| `ACCESS_FINE_LOCATION` | Real-time GPS tracking |
| `ACCESS_COARSE_LOCATION` | Approximate location fallback |
| `ACCESS_BACKGROUND_LOCATION` | Track location when app is minimized |
| `FOREGROUND_SERVICE` | Keep location service running |
| `POST_NOTIFICATIONS` | Foreground service notification (Android 13+) |
| `INTERNET` | Firebase & map tile connectivity |
| `WAKE_LOCK` | Prevent CPU sleep during tracking |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Reliable background tracking |

---

## 👨‍💻 Author

**Rushit Trambadia**

---

## 🔒 Privacy Policy

**NOLB Privacy Policy**

**Information Collection & Use**
NOLB focuses on keeping your convoy together in real-time. We only collect the minimal data required for real-time tracking, such as:
*   **Location Data**: Your live location is securely processed and temporarily stored on Firebase Realtime Database. It is only shared with active members of the convoy you join. Location tracking occurs in the background when you grant the "Allow all the time" permission to keep you connected while your device is locked or routing is active in another app.
*   **Camera & Photos**: Used for features such as sharing images in trip chat and capturing profile photos. Face detection is conducted entirely on-device using MLKit and no facial recognition data is transmitted or stored.

**Data Retention**
*   Active trip details, chat, and location data are deleted upon trip expiration or disbandment.
*   Trip histories are saved locally on your device for your reference and are not stored permanently by us on remote servers.

**Third-Party Services**
NOLB uses the following third-party services:
*   Firebase Realtime Database (for synchronized tracking and chats)
*   Cloudinary (for temporary image hosting during chat) 

By using NOLB, you consent to this policy and the collection of real-time data strictly for convoy tracking functionality.

---

## 📄 License

This project is proprietary. All rights reserved.
