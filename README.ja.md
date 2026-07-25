[![中文](https://img.shields.io/badge/中文-red)](README.md)
[![English](https://img.shields.io/badge/English-blue)](README.en.md)
[![Русский](https://img.shields.io/badge/Русский-green)](README.ru.md)
[![日本語](https://img.shields.io/badge/日本語-当前-brightgreen)](README.ja.md)
[![한국어](https://img.shields.io/badge/한국어-purple)](README.ko.md)

# RJDC-Poker — マジックポーカー

> [!WARNING]
> このドキュメントは大規模言語モデル（AI）によって翻訳されました。翻訳には不正確な部分が含まれる可能性があります。正確な情報については[中国語版](README.md)を参照してください。

[Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker) をフォークし、Android スマートフォン向けに最適化、デフォルトでクラシックなマジックスワイプモードを使用します。

**原作者**: [HuaweiREN](https://github.com/HuaweiREN) — [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker)

**フォーク作者**: [RenJDC](https://github.com/RenJDC)

---

## ✨ 機能

### エフェクト

起動後、画面は**完全に真っ黒**になり、ボタンやテキストは一切表示されません — これはマジックパフォーマンスのリアリティを高めるための意図的なデザインです。観客は電話に異常があることに気づきません。

### 操作方法

1. **ランク選択**: 15 のグリッドセル（3列×5行）をタップしてランク（A–K、小ジョーカー、大ジョーカー）を選びます

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
   │  K  │ 小J  │ 大J  │
   └─────┴─────┴─────┘
   ```
2. **スート選択**: ランク選択後、画面の**任意の場所でスワイプ**してスートを選びます
   - ⬆️ **上スワイプ** = スペード &nbsp;&nbsp; ➡️ **右スワイプ** = ハート
   - ⬇️ **下スワイプ** = クラブ &nbsp;&nbsp; ⬅️ **左スワイプ** = ダイヤ
3. 対応するトランプカード画像がすぐに表示されます
4. **待機画面に戻る**: カード画像をタップして、真っ黒な待機画面に戻ります

### 特殊操作

- **小ジョーカー / 大ジョーカー**: グリッド下部中央/右のセルをタップすると、スワイプなしで直接カードが表示されます
- **誤タッチ防止**: 8px 未満のスワイプは無視されます。必要に応じて再度スワイプしてください

## 📱 ダウンロード

APK は [Releases](../../releases) から入手するか、ソースからビルドしてください。

## 🛠️ ビルド

```bash
flutter pub get
flutter build apk --release
```

> 中国国内のネットワークではミラーを設定：
> ```bash
> export PUB_HOSTED_URL=https://pub.flutter-io.cn
> export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
> ```

## 🔧 オリジナルとの違い

- デフォルトモードを `GridSwipeCardSelector`（クラシックマジックスワイプモード）に変更
- 操作を**2ステップ式**に変更：タップでランク選択 → スワイプでスート選択
- 方向判定に `|dx| > |dy|` 絶対値比較を使用、斜めスワイプでスートが誤判定されなくなった
- 音声関連の依存関係を削除（`sherpa_onnx`、`flutter_sound`、`permission_handler` 等）
- 音声モデルアセットを削除、APK サイズを ~70MB から ~29MB に削減
- 待機画面から戻った後の最初のタップが無視される問題を修正

## 📁 プロジェクト構造

```
lib/
├── main.dart                  # エントリーポイント：アプリ初期化、状態管理
├── card_selector.dart         # CardSelector 抽象インターフェース
├── grid_swipe_selector.dart   # マジックモード：タップ→スワイプ
└── custom_selector.dart       # その他のセレクター（未使用、参考用）

android/app/src/main/
└── AndroidManifest.xml        # Android設定：アプリ名、権限

assets/
└── images/                    # トランプ画像（heitao_A.png, hongtao_5.png 等）

pubspec.yaml                   # プロジェクト設定：依存関係、アセット、バージョン
```

## 🙏 謝辞

- **原作者** [HuaweiREN](https://github.com/HuaweiREN) と彼の [Wombat_Magic_Poker](https://github.com/HuaweiREN/Wombat_Magic_Poker)
- Bilibili [**barry巴里里**](https://space.bilibili.com/your-uid) の動画コンセプトに触発されました
- カード画像アセット提供元 [GitCode](https://gitcode.com/open-source-toolkit/77d38/)

## 📄 ライセンス

デュアルライセンス：

- **オリジナルコード**（Wombat_Magic_Poker）：[MIT License](LICENSE) — Copyright (c) 2026 HuaweiREN
- **修正および追加コード**（RenJDC）：[GNU General Public License v3.0](LICENSE-GPLv3)

修正版を使用する際は、GPLv3 のオープンソース要件に従ってください。
