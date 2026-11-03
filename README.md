# FloatDraft

macOS のメニューバーに常駐する、小さな下書きパネルです。日本語変換を確定する Return や、改行のつもりの Return でメッセージを誤送信する事故を防ぎます。

[Mac App Store で入手（無料）](https://apps.apple.com/jp/app/floatdraft/id6826853260)

[English](#english)

## できること

- **⌃⇧Space**（変更可能）で、どのアプリからでもパネルを開く
- パネルの中では **Return は常に改行**。送信操作がないので、何度押しても送られない
- 変換中の Return、Esc、⌘Return は入力メソッドだけが受け取る
- **⌘Return** でコピーして消去し、元のアプリに戻る。あとは ⌘V で貼り付けるだけ
- 引用、コードブロック、空白の整理（どれも ⌘Z で戻せる）
- 履歴（最新 30 件とピン留め）、サービスメニュー、ショートカット App のアクション

## プライバシー

- ネットワークの権限を持たず、通信しません。データはすべてこの Mac の中に保存します
- アクセシビリティや入力監視の権限を使いません
- クリップボードは書き込むだけで、読みません

権限は `com.apple.security.app-sandbox` だけです（[entitlements](FloatDraft/Support/FloatDraft.entitlements)）。[`scripts/verify.sh`](scripts/verify.sh) が、entitlements、禁止 API、クリップボードの読み取りを検査します。

## ビルド

macOS 14 以降で動きます。ビルドには Xcode と [XcodeGen](https://github.com/yonaskolb/XcodeGen) が必要です（Xcode 27.2 で確認）。Apple Developer のアカウントは要りません（アドホック署名でビルドします）。

```bash
brew install xcodegen
scripts/verify.sh --quick
open build/DerivedData/Build/Products/Debug/FloatDraft.app
```

設計の詳細は [docs/SPEC.md](docs/SPEC.md)、テストの方針は [docs/TESTING.md](docs/TESTING.md) にあります。

## 不具合の報告と開発への参加

不具合の報告や要望は [Issue](../../issues) へどうぞ。個人で開発しているので、返信や Pull Request への対応はできないことがあります。

## ライセンス

コードは [MIT License](LICENSE) で公開しています。利用しているライブラリのライセンスは [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) にあります。

**「FloatDraft」の名称とアプリアイコン**（`FloatDraft/Resources/AppIcon.icon` と、それを描く `scripts/make-app-icon.swift`）は MIT License の対象外です。改変版を配布するときは、別の名称とアイコンを使い、バンドル ID も変更してください。

---

## English

FloatDraft is a small draft panel for the macOS menu bar. It prevents half-written messages from being sent by a Return meant for a new line or for confirming input-method text.

[Get it on the Mac App Store (free)](https://apps.apple.com/app/floatdraft/id6826853260)

- Open the panel from any app with **⌃⇧Space** (customizable)
- **Return is always a line break** in the panel: there is no send
- While an input method is composing, Return, Esc and ⌘Return go to the input method only
- **⌘Return** copies and clears the draft and returns you to the previous app
- **Private by design**: no network entitlement, no Accessibility or Input Monitoring permission, and it never reads the clipboard. The only entitlement is the app sandbox

### Build

Requires macOS 14 or later, Xcode (tested with 27.2) and [XcodeGen](https://github.com/yonaskolb/XcodeGen). No Apple Developer account is needed.

```bash
brew install xcodegen
scripts/verify.sh --quick
open build/DerivedData/Build/Products/Debug/FloatDraft.app
```

Project documents are in Japanese.

### Issues and contributions

Bug reports and requests are welcome in [Issues](../../issues). This is a personal project, so replies and pull requests may not always be handled.

### License

The code is released under the [MIT License](LICENSE). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for third-party licenses.

**The "FloatDraft" name and app icon** (`FloatDraft/Resources/AppIcon.icon` and `scripts/make-app-icon.swift`, which draws it) are not covered by the MIT License. If you distribute a modified version, please use a different name, icon and bundle ID.
