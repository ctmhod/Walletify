# Third-party notices

Walletify is a modified version of [Ivy Wallet](https://github.com/Ivy-Apps/ivy-wallet) (GPL-3.0, Copyright (C) Ivy Apps and contributors). The full license text is in [LICENSE](LICENSE).

The app uses the following open-source projects, icons and fonts. Each is used under its own license; see the linked project for the license text.


## Icons

- [iconsax](https://iconsax.io)
- [Material Symbols Google](https://fonts.google.com/icons)
- [coolicons](https://github.com/krystonschwarze/coolicons)

## Fonts

- [Open Sans](https://fonts.google.com/specimen/Open+Sans)
- [Raleway](https://fonts.google.com/specimen/Raleway?query=raleway)
- [Nunito Sans](https://fonts.google.com/specimen/Nunito+Sans?query=nunito)

## Tech Stack

- [Kotlin](https://kotlinlang.org)
- [Jetpack Compose](https://developer.android.com/jetpack/compose)
- [Kotlin Coroutines](https://kotlinlang.org/docs/coroutines-overview.html)
- [Kotlin Flow](https://kotlinlang.org/docs/flow.html)
- [Hilt](https://dagger.dev/hilt)
- [ArrowKt](https://arrow-kt.io)
- [Kotest](https://kotest.io)
- [DataStore](https://developer.android.com/topic/libraries/architecture/datastore)
- [Room DB](https://developer.android.com/training/data-storage/room)
- [Ktor Client](https://ktor.io/docs/getting-started-ktor-client.html)
- [KotlinX Serialization](https://github.com/Kotlin/kotlinx.serialization)
- [Gradle KTS (Kotlin DSL)](https://docs.gradle.org/current/userguide/kotlin_dsl.html)
- [Fastlane](https://fastlane.tools)
- [Github Actions](https://github.com/ctmhod/Walletify/actions)
- [Timber](https://github.com/JakeWharton/timber)
- [Detekt](https://github.com/detekt/detekt)
- [Ktlint](https://github.com/pinterest/ktlint)
- [Slack's compose-lints](https://slackhq.github.io/compose-lints)

## Exchange rates

Rates are downloaded from free, key-less sources and cached on the device:

- [fawazahmed0/exchange-api](https://github.com/fawazahmed0/exchange-api) (CC0), served by jsDelivr and Cloudflare Pages. Daily rates, no rate limits.
- Fallback: [ExchangeRate-API open access](https://www.exchangerate-api.com) (rates by [ExchangeRate-API](https://www.exchangerate-api.com)). Daily rates, rate limited.
