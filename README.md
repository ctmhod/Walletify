# Walletify

An offline money manager for Android, based on [Ivy Wallet](https://github.com/Ivy-Apps/ivy-wallet) (GPL-3.0, no longer maintained upstream).

## Changes from Ivy Wallet
- New name, icon and application id (`com.ctmhod.walletify`), so it installs beside Ivy Wallet.
- No Firebase, no crash reporting, no telemetry, no polls. Your data stays on the device. The only network use is the optional exchange-rate download.
- Release APKs are split per CPU architecture, plus one universal APK.

## Download
Open the latest release and start with `Walletify-vX-0-universal.apk` (works everywhere).
Smaller files: `arm64-v8a` (most phones and tablets), `armeabi-v7a` (old 32-bit devices), `x86_64` (emulators).

## License
GPL-3.0, see [LICENSE](LICENSE). This is a modified version of Ivy Wallet, Copyright (C) Ivy Apps and contributors. The Ivy name and logo are not used here.

## Privacy
Walletify sends none of your data anywhere: no accounts, analytics, ads or crash reporting (exchange rates are downloaded on request). Everything is stored locally on your device.

## Developer
Telegram: [@ctmhod](https://t.me/ctmhod)
