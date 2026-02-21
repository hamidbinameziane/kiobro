# GEMINI.md - Kiobro Project Context

## Project Overview
**Kiobro** is a minimalist, kiosk-style web browser built with Flutter. It is designed to provide a controlled browsing experience where users can curate a list of "allowed" websites and navigate only within those domains. The application features an immersive UI, ad-blocking capabilities, and local persistence for site management.

### Main Features
- **Curated Site List:** Users can add, delete, and reorder a list of allowed websites.
- **Restricted Browsing:** The integrated web view prevents navigation to any site not explicitly included in the allowed list.
- **Immersive Mode:** The app runs in `immersiveSticky` mode to maximize screen real estate.
- **Content Filtering:** Basic ad-blocking and DOM-based popup removal are implemented within the web view.
- **Metadata Fetching:** Automatically attempts to fetch and cache website titles using their `<title>` tags.
- **Discrete Navigation:** A double-tap gesture in the top-left corner serves as a hidden "back to home" action.

## Tech Stack
- **Framework:** [Flutter](https://flutter.dev/) (Dart)
- **Web Engine:** [flutter_inappwebview](https://pub.dev/packages/flutter_inappwebview)
- **Persistence:** [shared_preferences](https://pub.dev/packages/shared_preferences)
- **Networking:** [http](https://pub.dev/packages/http)
- **Icons:** Cupertino and Material Icons

## Project Structure
- `lib/main.dart`: Entry point. Initializes the app and enables system-wide immersive mode.
- `lib/home_page.dart`: The dashboard for managing the list of sites. Handles URL sanitization, title fetching, and reorderable lists.
- `lib/browser_page.dart`: The core browsing component. Implements the `InAppWebView` with custom navigation policies, request interception for ad-blocking, and JS injection for cleanup.

## Building and Running

### Prerequisites
- Flutter SDK (version specified in `pubspec.yaml`, currently `^3.11.0`)
- Android Studio / Xcode for mobile deployment

### Commands
- **Install Dependencies:** `flutter pub get`
- **Run App:** `flutter run`
- **Build Android APK:** `flutter build apk`
- **Build iOS (macOS only):** `flutter build ios`
- **Run Tests:** `flutter test`

## Development Conventions
- **Code Style:** Follows standard Flutter/Dart linting rules defined in `analysis_options.yaml` (using `flutter_lints`).
- **State Management:** Uses local `StatefulWidget` state for page-level logic.
- **Navigation:** Standard `Navigator` push/pop for moving between the home list and the browser.
- **Security:** Navigation is strictly limited via `shouldOverrideUrlLoading` in the web view.
- **Persistence:** All user-defined sites and titles are stored locally on the device via `SharedPreferences`.
