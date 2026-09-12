# PDF Master Tools V2 — Android Studio Build

Release identity: **2.0.0+12**

## Open the project
1. Extract this ZIP on Windows.
2. Open Android Studio.
3. Choose **File → Open**.
4. Select the project folder that contains `pubspec.yaml`, `android`, `lib`, and `assets`.
5. Do **not** open the `android` subfolder alone.

## First checks
Open Android Studio Terminal and run:

```powershell
flutter doctor
flutter pub get
flutter analyze
```

Fix any `flutter doctor` setup issue before building.

## Debug test
Connect an Android phone with USB debugging enabled, select it in Android Studio, then run:

```powershell
flutter run
```

Test: Home, Library, camera scanner, auto-crop, multi-page scan, PDF editor, OCR (English/Urdu/Arabic), translation, TTS, QR, sharing, file opening, and ads.

## Release AAB
Only after debug testing passes:

```powershell
flutter build appbundle --release
```

The final Play Console upload must use version **2.0.0 (12)**. Do not increment the version merely for another local build.

## Important
This project has not been compiled in this environment. Android Studio/Flutter/Gradle and a real Android device are the authoritative final verification step.
