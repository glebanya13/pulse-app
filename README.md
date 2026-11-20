# ⚡ Pulse

Pulse is a sleek, cross-platform mobile application engineered for discovering parties, concerts, nightlife, cultural exhibitions, and city events. Built with Flutter, Riverpod, and Yandex MapKit, Pulse connects urban explorers, music enthusiasts, and party-goers with real-time event feeds, interactive venue maps, live attendee chatrooms, and instant ticket bookings.

---

## 🚀 Features

- **🔥 Curated Event Feed**: Discover top parties, concerts, DJ sets, festivals, theater, and exhibitions filtered by category, date, and vibe.
- **🗺️ Interactive Geolocation Map**: Powered by Yandex MapKit Lite and device GPS to locate nearby happenings, trending clubs, and bars with real-time distance calculation.
- **💬 Real-Time Live Chatrooms**: Socket.IO integration enabling real-time community chatrooms for each event, allowing attendees to coordinate meetups and share photos.
- **📍 Detailed Venue & Place Guides**: Explore clubs, rooftop bars, underground spaces, and concert halls with full descriptions, schedules, reviews, and photo galleries.
- **🎟️ Event Submissions & Organizer Tools**: In-app workflow for event hosts and promoters to submit new events, request venue attachments, and track review status.
- **🔔 Push Notifications & Smart Alerts**: Firebase Cloud Messaging (FCM) integration delivering timely reminders for saved events, friend invites, and chat mentions.
- **🔐 Frictionless Authentication**: Sign in with Apple, Google Sign-In, or secure phone/email authentication with token management.
- **💖 Social Bookmarks & Favorites**: Save upcoming events to your personal calendar, track favourite organizers, and share events via native share sheets.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (`Dart >=3.10.8`)
- **State Management**: [Riverpod (`flutter_riverpod: ^2.6.1`)](https://riverpod.dev/) for clean, reactive, and declarative state orchestration
- **Routing**: [GoRouter (`go_router: ^14.8.1`)](https://pub.dev/packages/go_router) with deep link routing and nested shells
- **Networking**: [Dio (`dio: ^5.7.0`)](https://pub.dev/packages/dio) with interceptors for JWT token attachment and auto-refresh
- **Maps & Geolocation**: [Yandex MapKit Lite (`yandex_maps_mapkit_lite: ^4.41.0`)](https://pub.dev/packages/yandex_maps_mapkit_lite) and `geolocator`
- **Real-Time Communication**: [Socket.IO Client (`socket_io_client: ^3.1.6`)](https://pub.dev/packages/socket_io_client) for low-latency live messaging
- **Cloud & Push Notifications**: Firebase Core, Firebase Auth (Apple & Google Sign-In), and Firebase Messaging (FCM)
- **UI & Image Caching**: `cached_network_image`, `image_picker`, `share_plus`, and Cupertino/Material icons

---

## 📦 Installation & Setup

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.10.8`)
- [Dart SDK](https://dart.dev/get-dart)
- Xcode 15+ (for iOS development)
- Android Studio / Android SDK (for Android development)
- [Yandex MapKit API Key](https://developer.tech.yandex.ru/)

### Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/glebanya13/pulse-app.git
   cd pulse-app
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Configure Environment & API Keys**:
   - Provide your backend endpoint in configuration.
   - Set up your Yandex MapKit API key:
     - **Android**: Update `android/app/src/main/AndroidManifest.xml` with your MapKit API key metadata.
     - **iOS**: Update `ios/Runner/AppDelegate.swift` with your MapKit credentials.
   - Configure Firebase:
     - Ensure `google-services.json` is placed in `android/app/`.
     - Ensure `GoogleService-Info.plist` is placed in `ios/Runner/`.

4. **Launch the application**:
   ```bash
   # Run on connected device or simulator
   flutter run

   # Target specific platform
   flutter run -d ios
   flutter run -d android
   ```

---

## 💻 Usage

1. **Explore the City Feed**: Browse events happening today, this weekend, or across custom date ranges.
2. **Switch to Map View**: Tap the map tab to discover nearby venues, active nightlife hotspots, and filter by walking distance.
3. **Join Event Chats**: Open any event page to chat with other guests before attending.
4. **Submit an Event**: Organizers can tap the `+` button in their profile to submit an event with poster art, location, and ticket links for moderation.

---

## 📂 Project Structure

```markdown
pulse-app/
|-- android/                        # Android native shell, permissions & Gradle setup
|-- assets/                         # Graphic assets, placeholder images, and icons
|-- ios/                            # iOS native runner, MapKit init & entitlements
|-- lib/
|    |-- main.dart                  # Application entry point & service bootstrap
|    |-- firebase_options.dart      # Auto-generated Firebase client credentials
|    |-- core/                      # Core infrastructure and shared foundations
|    |    |-- config/               # App constants, API endpoints & keys
|    |    |-- geo/                  # Geolocation calculation & distance helpers
|    |    |-- mapkit/               # Yandex MapKit controller & pin builders
|    |    |-- providers/            # Global dependency injection providers
|    |    |-- router/               # GoRouter route declarations & navigation guards
|    |    |-- theme/                # Custom dark/light theme, typography & palettes
|    |    |-- utils/                # Date formatters, string utils & validators
|    |    `-- widgets/              # Reusable UI controls, buttons & loaders
|    |-- data/                      # Data layer, network clients & repositories
|    `-- features/                  # Domain-driven feature modules
|         |-- admin/                # Event moderation & management controls
|         |-- auth/                 # Sign in with Apple, Google & token flows
|         |-- chat/                 # Real-time event & direct messaging (Socket.IO)
|         |-- events/               # Event detail views, lineups & ticket links
|         |-- feed/                 # Curated event feed, search & category filters
|         |-- map/                  # Full-screen interactive map with venue clusters
|         |-- monetization/         # Promoted listings & ticket purchase flows
|         |-- notifications/        # Push notification list & activity history
|         |-- places/               # Venue catalog, bar profiles & photo sliders
|         |-- profile/              # User settings, bookmarks & ticket wallet
|         `-- requests/             # Organizer submission forms & status tracking
|-- pubspec.yaml                    # Dart & Flutter dependencies
`-- test/                           # Unit and widget test suite
```

---

## 🤝 Contributing

Contributions are welcome! Please follow standard Git practices:
1. Fork the repository: `git fork https://github.com/glebanya13/pulse-app.git`
2. Create your feature branch: `git checkout -b feature/awesome-feature`
3. Commit your changes: `git commit -m "feat: Add new map marker filter"`
4. Push to branch: `git push origin feature/awesome-feature`
5. Open a Pull Request.

---

## 📝 License

This project is licensed under the **MIT License**.

---

## 📬 Contact

For inquiries or feedback:
- **Author**: [@glebanya13](https://github.com/glebanya13)
- **Email**: [glebanya.com@gmail.com](mailto:glebanya.com@gmail.com)
- **Issues**: [GitHub Issues](https://github.com/glebanya13/pulse-app/issues)
