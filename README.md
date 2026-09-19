# PDF Master Tools V2 — Android + Windows Edition

The Android release keeps the full mobile scanner/OCR/translation workflow. A Windows desktop target is included for laptop-based PDF/document testing. See `WINDOWS_EDITION.md`.

# PDF Master Tools

A complete, production-ready Flutter PDF toolkit for Android: merge, split,
compress, convert, reorder, rotate, fill forms, fill & sign, secure, and
manage PDFs, plus a QR scanner/generator — all built around a Library +
Recently Deleted system, ready for Google Play.

This project is built for **cloud-only building**: everything compiles via
GitHub Actions, no local Flutter/Android SDK required.

## Project structure

```
lib/
  core/            theme, storage, services (file/PDF/ads), shared widgets
  features/
    home/          Home tab
    library/       Library tab
    tools/         Tools tab + all 12 tool screens
    fill_sign/     Fill & Sign canvas + signature pad
    reader/        PDF reader
    qr/             QR scanner + generator
    trash/         Recently Deleted
    settings/      Settings
  models/          DocumentItem, TrashItem, ToolHistoryEntry
android/           Full native Android project (Kotlin, Gradle Kotlin DSL)
.github/workflows/ CI: build.yml
```

## Building via GitHub Actions (no local SDK needed)

1. Push this repo to GitHub.
2. Go to **Actions -> Build Android -> Run workflow** to build manually, or
   just push to `main` for a fast debug-APK correctness check on every
   push.
3. For a **release** APK/AAB (signed, ready for Google Play), check
   "Also build a release APK + AAB" when running the workflow manually,
   after configuring the secrets below.
4. Download the built APK/AAB from the workflow run's **Artifacts**
   section.

### Required GitHub Secrets (Settings -> Secrets and variables -> Actions)

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Your release keystore (`.jks`), base64-encoded: `base64 -w0 release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ADMOB_BANNER_UNIT_ID` | Your real AdMob banner ad unit ID |
| `ADMOB_INTERSTITIAL_UNIT_ID` | Your real AdMob interstitial ad unit ID |
| `PRIVACY_POLICY_URL` | Your hosted Privacy Policy URL (shown in Settings) |
| `SYNCFUSION_LICENSE_KEY` | Syncfusion license key (see below) — without it, the PDF reader shows a trial watermark |

### Syncfusion license

This project uses Syncfusion's Flutter PDF library (merge/split/rotate/
security/fill) and PDF viewer (reader screen). These require a Syncfusion
license key to run without a trial watermark. Syncfusion offers a **free
Community License** for individuals and small businesses under a revenue
threshold — register at https://www.syncfusion.com/products/communitylicense
and add the generated key as the `SYNCFUSION_LICENSE_KEY` secret above.

If these secrets aren't set, release builds still succeed — they fall back
to Google's public **test** AdMob IDs and the debug signing key, so you can
verify the build pipeline before you have real credentials. **Do not
publish a build signed with the debug key or using test ad units.**

You'll also need to set your real AdMob **App ID** (different from the ad
unit IDs above) in `android/app/build.gradle.kts`
(`manifestPlaceholders["admobAppId"]`) or pass it as a Gradle property —
it currently defaults to Google's public test App ID.

### Generating a release keystore

```
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Keep this file and its passwords private — losing it means you can never
update your app on Google Play under the same listing again.

## Architecture notes

- **Storage**: every document lives in exactly one place on disk at a
  time (`FileStorageService`). Delete moves a file from `library/` to
  `trash/` (never copies), which is what makes the Recently Deleted
  system atomic — no double-delete bugs, no files reappearing.
- **Tool history vs Library**: removing a tool's history entry only
  deletes that record; the underlying saved file and its Library entry
  are untouched, per spec.
- **Fill vs Fill & Sign**: `Fill PDF` looks for real AcroForm fields and
  fills/flattens them natively. If none exist, it offers `Fill & Sign`,
  which lets you place a signature or text anywhere via a draggable/
  resizable overlay that coexists correctly with two-finger pinch zoom.
- **Ads**: `AdsService` frequency-caps interstitials (minimum gap + a
  minimum number of completed tool actions between them) and banners
  collapse to zero size when no ad is available, so the UI never looks
  broken offline or before ads finish loading.

## Before publishing to Google Play

- [ ] Add your real AdMob App ID + ad unit IDs (see above)
- [ ] Add a Syncfusion license key (see above) — otherwise the PDF reader shows a trial watermark
- [ ] Generate and secure a real release keystore
- [ ] Host a real Privacy Policy and update the link in Settings
- [ ] Run the release build once via manual workflow dispatch and
      install/test the APK on a real device
- [ ] Review Play Console's Data Safety form against what this app
      actually collects/stores (all data is local-only by default)
- [ ] Integrate Google's User Messaging Platform (UMP) SDK for GDPR/consent
      handling if you'll have EEA/UK users — `AdsService` initializes ads
      unconditionally and does not currently request consent, which Google
      requires for those regions
- [ ] Google Play now requires native libraries to support 16 KB memory
      page sizes for apps targeting recent API levels. This project can't
      verify that here (no local Android SDK), so run
      `flutter build appbundle --release` via the CI workflow and check
      Play Console's pre-launch report — if any bundled plugin ships an
      outdated native `.so`, update that plugin to its latest version


## PDF Master Tools V2 foundation

The V2 development starts with a dedicated Smart Scanner flow. Capture, preview and basic enhancement are isolated so native/OpenCV document-edge detection can be integrated next without replacing the user-facing flow. OCR, translation, text-to-speech, advanced search and the final scanner pipeline are planned as subsequent modules.


## Current release identity
V2 final candidate: **2.0.0+12**. The published Play release is **1.0.7+11**. Build/test before Play submission.
