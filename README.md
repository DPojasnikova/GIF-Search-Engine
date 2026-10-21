# Flutter developer

## The Task:
- Create a gif search application using the Giphy service;

### Primary Requirements:
## Technical
- Primary platforms - iOS & Android;
- Auto search - requests to retrieve Gif information from the service are made automatically with a small delay after user stops typing;
- Pagination - loading more results when scrolling;
- Vertical & horizontal orientation support;
- Error handling;
- Unit tests - as much as you see fit;
  
## UI
- Responsive & matching platform guidelines;
- At least 2 views sourced by data from Giphy;
- Results are displayed in a grid;
- Clicking on a grid item should navigate to a detailed Gif view.
- Loading indicators;
- Error display;

### Bonus points (not needed at the first stage):
- Using state management approaches or libraries such as BLoC (flutter_bloc), Riverpod or others;
- Using an understandable architecture pattern;
- Page navigation is separate from page widget code (a Coordinator pattern or similar);
- Network availability handling;

### Notes:
- No time limit. Quality > Speed;
- Documentation (https://developers.giphy.com/docs/api/)
- UI up to interpretation - only things mentioned in requirements are mandatory;
- Flutter version MUST be noted in repository ReadMe file;
- If you were not able to complete some of the requirements, please note down what you tried and what was the result;

---

# GIF Search (implementation)

A simple app for searching gifs with the [Giphy API](https://developers.giphy.com/docs/api/).

## Flutter version

**Flutter 3.47.7** (stable, Dart 3.13.5)

## What is implemented

- Auto search: the request is sent 0.5 seconds after the user stops typing
- While the search field is empty, trending gifs are shown
- Pagination: the next page is loaded while scrolling
- Portrait and landscape orientations (landscape has more grid columns)
- Error handling: no internet, invalid key, rate limit, server error, broken response. There is a "Retry" button
- Two views with Giphy data: a grid of results and a detail screen for one gif
- Loading indicators (first page, next page, every image)
- Light and dark themes (Material 3), taken from the phone settings
- Automated tests (`flutter test`, 29 tests): Giphy model and requests, auto search delay, pagination, loading indicators, error handling, grid columns in portrait and landscape, floating search field, navigation to the detail screen

## Structure

```
lib/
  main.dart                    - app start and theme
  config.dart                  - API key and settings (not committed to git)
  config.example.dart          - template for config.dart
  gif_model.dart               - Gif class
  giphy_api.dart               - requests to Giphy
  screens/search_screen.dart   - search screen with the grid
  screens/detail_screen.dart   - screen of one gif
test/                          - tests (giphy_api_test, search_screen_test, detail_screen_test)
```

## How to run

1. Get a free key at https://developers.giphy.com (Create an App -> API)
2. Copy `lib/config.example.dart` to `lib/config.dart` and paste the key
3. `flutter pub get`
4. `flutter run`

## Running the app on Android

A ready-to-install release build is included in the repository:

**`build/gif_search.apk`**

To install it on a real Android phone:

1. Copy `build/gif_search.apk` to the phone (USB cable, cloud drive, messenger, etc.)
2. Open the file on the phone. If Android asks, allow installing apps from this source
   (Settings -> Apps -> Special access -> Install unknown apps)
3. Tap "Install" and then "Open". The app is called "GIF Search"
4. The phone needs an internet connection to load gifs

The same file can also be installed from a computer with `adb install build/gif_search.apk`.

To build the APK again after changing the code, run `flutter build apk --release`.
Flutter puts the result in `build/app/outputs/flutter-apk/app-release.apk`.

Note: the APK is signed with the debug key, so it is good for testing but not for publishing to Google Play.
There is no iOS build file, because building for iOS requires a Mac.

## What is not done

The bonus items (state management, Coordinator, separate network availability check) were intentionally skipped: the project is written as simply as possible with `StatefulWidget`. Network problems are handled through request errors. The app was tested on an Android emulator. It was not run on iOS because a Mac is required.
