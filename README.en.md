[![中文](https://img.shields.io/badge/中文-red)](README.md)
[![English](https://img.shields.io/badge/English-当前-brightgreen)](README.en.md)
[![Русский](https://img.shields.io/badge/Русский-green)](README.ru.md)
[![日本語](https://img.shields.io/badge/日本語-orange)](README.ja.md)
[![한국어](https://img.shields.io/badge/한국어-purple)](README.ko.md)

# RJDC-Poker — Magic Poker

> [!WARNING]
> This document was translated by a Large Language Model (AI). Translations may contain inaccuracies. Please refer to the [Chinese version](README.md) for the most accurate information.

Forked from [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker), optimized for Android phones, defaults to the classic magic swipe mode.

**Original Author**: [HuaweiREN](https://github.com/HuaweiREN) — [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker)

**Fork Author**: [RenJDC](https://github.com/RenJDC)

---

## ✨ Features

### Effect

When launched, the screen appears **completely black**, with no buttons or text — this is intentional for realistic magic performances. The audience will not notice anything unusual about the phone.

### How to Use

1. **Select Rank**: Tap any of the 15 grid cells (3 columns × 5 rows) to choose a rank (A–K, Small Joker, Big Joker)

   ```
   ┌─────┬─────┬─────┐
   │  A  │  2  │  3  │
   ├─────┼─────┼─────┤
   │  4  │  5  │  6  │
   ├─────┼─────┼─────┤
   │  7  │  8  │  9  │
   ├─────┼─────┼─────┤
   │ 10  │  J  │  Q  │
   ├─────┼─────┼─────┤
   │  K  │  SJ  │  BJ │
   └─────┴─────┴─────┘
   ```
2. **Select Suit**: After selecting the rank, **swipe anywhere** on the screen to choose the suit
   - ⬆️ **Swipe Up** = Spades &nbsp;&nbsp; ➡️ **Swipe Right** = Hearts
   - ⬇️ **Swipe Down** = Clubs &nbsp;&nbsp; ⬅️ **Swipe Left** = Diamonds
3. The corresponding playing card image is displayed immediately
4. **Return to Standby**: Tap the card image to return to the all-black standby screen

### Special Operations

- **Small Joker / Big Joker**: Tap the bottom-center / bottom-right cell — the card is shown directly without swiping
- **Accidental Touch Protection**: Swipes shorter than 8px are ignored; swipe again if needed

## 📱 Download

APK available in [Releases](../../releases), or build from source.

## 🛠️ Build

```bash
flutter pub get
flutter build apk --release
```

> For users in China, configure mirrors:
> ```bash
> export PUB_HOSTED_URL=https://pub.flutter-io.cn
> export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
> ```

## 🔧 Differences from Original

- Default mode changed to `GridSwipeCardSelector` (classic magic swipe mode)
- Interaction changed to **two-step**: tap to select rank, then swipe to select suit
- Direction detection uses `|dx| > |dy|` absolute comparison, diagonal swipes no longer trigger wrong suits
- Removed voice dependencies (`sherpa_onnx`, `flutter_sound`, `permission_handler`, etc.)
- Removed voice model assets, APK reduced from ~70MB to ~29MB
- Fixed issue where first tap after returning to standby was ignored

## 📁 Project Structure

```
lib/
├── main.dart                  # Entry point: initialize app, manage standby/display states
├── card_selector.dart         # Abstract CardSelector interface
├── grid_swipe_selector.dart   # Classic magic mode: tap rank → swipe suit
└── custom_selector.dart       # Other selectors (unused, kept for reference)

android/app/src/main/
└── AndroidManifest.xml        # Android config: app name, permissions

assets/
└── images/                    # Playing card images (heitao_A.png, hongtao_5.png, etc.)

pubspec.yaml                   # Project config: dependencies, assets, version
```

## 🙏 Acknowledgements

- **Original Author** [HuaweiREN](https://github.com/HuaweiREN) and his [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker)
- Inspired by Bilibili [**barry巴里里**](https://space.bilibili.com/your-uid) video concepts
- Card assets from [GitCode](https://gitcode.com/open-source-toolkit/77d38/)

## 📄 License

Dual-licensed:

- **Original code** (Wombat_Magic_Poker): [MIT License](LICENSE) — Copyright (c) 2026 HuaweiREN
- **Modifications and additions** (RenJDC): [GNU General Public License v3.0](LICENSE-GPLv3)

When using the modified version, please comply with the GPLv3 open-source requirements.
