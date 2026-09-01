# tyf_mobile (Track Your Finances Mobile App)

The cross-platform mobile client for **Track Your Finances (TYF)**, built with **Flutter** and **Material 3**.

---

## 📱 Features

- **Cross-Platform**: Runs seamlessly on iOS and Android.
- **Modern UI**: Clean, intuitive interface with Material 3 styling.
- **REST Integration**: Communicates directly with the `tyf_backend` API.

---

## 📁 Folder Structure

```text
tyf_mobile/
├── android/                  # Native Android configuration
├── ios/                      # Native iOS configuration
├── lib/                      # Flutter source code
│   └── main.dart             # Application entrypoint
├── test/                     # Widget and unit tests
│   └── widget_test.dart
├── pubspec.yaml              # Flutter dependencies and assets
└── analysis_options.yaml     # Dart analysis and linting rules
```

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `3.x` with Dart `3.8+`)
- **iOS**: macOS with Xcode & CocoaPods installed (`sudo gem install cocoapods`)
- **Android**: Android Studio with Android SDK & emulator configured

Check your Flutter environment health:
```bash
flutter doctor
```

---

### 2. Install Dependencies
```bash
cd tyf_mobile
flutter pub get
```

---

### 3. Run the App

#### List available simulators/devices:
```bash
flutter devices
```

#### Run on a connected device / simulator:
```bash
flutter run
```

#### Run on a specific target:
```bash
# iOS Simulator
flutter run -d iPhone

# Android Emulator
flutter run -d emulator-5554

# Chrome (Web)
flutter run -d chrome
```

---

## 🧪 Running Tests

Run Flutter unit and widget tests:
```bash
flutter test
```

---

## 🔗 Backend Connection

By default, ensure your backend server (`tyf_backend`) is running on `http://127.0.0.1:8000`.
- **iOS Simulator**: Access backend via `http://127.0.0.1:8000` or `http://localhost:8000`
- **Android Emulator**: Access backend via `http://10.0.2.2:8000` (Android host loopback alias)
