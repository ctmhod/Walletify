# Walletify

<p align="center">
  <img src="docs/icon.png" width="128" alt="Walletify icon">
</p>

An offline money manager for Android. Your data stays on your device.

## Features
- No Firebase, no crash reporting, no telemetry, no polls. The only network use is the optional exchange-rate download.
- Error log in Settings (Copy and Clear), redacted, also records crashes. Nothing is sent anywhere.
- Its own application id (`com.ctmhod.walletify`), so it installs beside any other app.
- Release APKs are split per CPU architecture, plus one universal APK.

## Screenshots

Screenshots captured on an Android emulator for v0.1.52 with demo data; current release: v0.1.57.

<p align="center">
  <img src="docs/screenshots/01-onboarding-agree.png" width="200" alt="Onboarding: terms and offline account">
  <img src="docs/screenshots/02-onboarding-end.png" width="200" alt="Onboarding: set your initial balance">
  <img src="docs/screenshots/03-home.png" width="200" alt="Home with demo transactions">
  <img src="docs/screenshots/04-home-more.png" width="200" alt="Home: more transactions">
  <img src="docs/screenshots/05-add-sheet.png" width="200" alt="Add income, expense or transfer">
  <img src="docs/screenshots/06-add-expense-keypad.png" width="200" alt="Adding an expense">
  <img src="docs/screenshots/07-menu.png" width="200" alt="Menu">
  <img src="docs/screenshots/08-categories.png" width="200" alt="Categories">
  <img src="docs/screenshots/09-planned-payments.png" width="200" alt="Planned payments">
  <img src="docs/screenshots/10-budgets.png" width="200" alt="Budgets">
  <img src="docs/screenshots/11-reports.png" width="200" alt="Reports">
  <img src="docs/screenshots/12-settings.png" width="200" alt="Settings">
  <img src="docs/screenshots/13-settings-more.png" width="200" alt="Settings: more options">
  <img src="docs/screenshots/14-check-updates.png" width="200" alt="Check for updates: you are on the latest version">
</p>

## Download
Requires Android 10 (API 29) or newer.
Open the [latest release](https://github.com/ctmhod/Walletify/releases/latest) and choose `Walletify-vX-all-universal.apk` first (works on every device).
Smaller per-CPU builds: `arm64-v8a` (most phones and tablets), `armeabi-v7a` (older 32-bit devices), `x86` and `x86_64` (emulators).

## License
GPL-3.0, see [LICENSE](LICENSE). Third-party credits: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Privacy
Walletify sends none of your data anywhere: no accounts, analytics, ads or crash reporting (exchange rates are downloaded on request). Everything is stored locally on your device.

## Developer
Telegram: [@ctmhod](https://t.me/ctmhod)
