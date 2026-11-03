# FloatDraft — App Store 提出資料

App Store Connect に入力する内容と、提出手順をまとめる。1.0.0 はこの内容をもとに公開済み。

---

## 1. 提出手順

1. **Archive と書き出し**（`<TEAM_ID>` は Apple Developer のチーム ID）
   ```bash
   scripts/verify.sh
   TEAM_ID=<TEAM_ID> scripts/archive.sh
   ```
   `build/export/FloatDraft.pkg` ができる。初回は自動署名が「Apple Distribution」証明書（クラウド管理）と App ID `jp.efukan.FloatDraft` を作る（1.0.0 / ビルド 1 で実施済み）。Apple のサーバーと通信せずに Archive できるかだけを確かめるなら、アドホック署名の `scripts/archive.sh --local` を使う
2. **App Store Connect でアプリを登録**: App ID が登録済みなので、新規 App のバンドル ID の一覧に出る。プラットフォーム macOS、プライマリ言語 日本語、SKU `floatdraft-mac`
3. **アップロード**: Transporter（インストール済み）に .pkg をドラッグ、または Xcode › Window › Organizer から
4. **スクリーンショット**: `swift scripts/make-screenshots.swift`（日英を `build/screenshots` に作る。先に Debug ビルドが必要。下の §6）
5. **App Store Connect で入力**: 下記のメタデータ、スクリーンショット、App のプライバシー、審査メモ
6. **URL**: 下の表の 3 つ。どれも efukan.jp（別リポジトリの efukan-pages、Cloudflare Pages で配信）に置く。**efukan-pages を push して本番に出てから入力・申請する**（審査の時点で開けないと却下される）
7. 審査に提出

| 欄 | 入れるもの | 備考 |
|---|---|---|
| サポート URL | `https://efukan.jp/apps/floatdraft/#contact` | Apple はサポート URL の先に連絡先があることを求める。紹介ページの末尾の「ご意見・不具合の報告」（X・GitHub） |
| マーケティング URL | `https://efukan.jp/apps/floatdraft/` | 任意 |
| プライバシーポリシー URL | `https://efukan.jp/privacy` | 全製品で共通のポリシー。FloatDraft は「第2部 各則7」（`#s-floatdraft`）。正本は efukan-pages の `privacy.html` で、[PRIVACY_POLICY.md](PRIVACY_POLICY.md) はその下書き |

App Store に出たら、efukan-pages 側でやること: 紹介ページの「Mac App Store で公開予定」を「App Storeで入手」のボタンに替える、トップの制作物にカードと更新履歴を足す、各則7の「（公開準備中）」を外す（efukan-pages の `NEXT.md` §3-0 の表も見る）。

### バージョン
- `MARKETING_VERSION`（表示バージョン）と `CURRENT_PROJECT_VERSION`（ビルド番号）は `project.yml` で管理する。アップロードのたびにビルド番号を上げる

---

## 2. 基本情報

| 項目 | 値 |
|---|---|
| 名前 | FloatDraft |
| サブタイトル（ja、30字以内） | 誤送信を防ぐ、どこでも下書きパネル |
| サブタイトル（en） | Draft safely, paste when ready |
| カテゴリ（プライマリ） | 仕事効率化（Productivity） |
| カテゴリ（セカンダリ） | ユーティリティ（Utilities） |
| 年齢制限 | 4+（該当するコンテンツなし） |
| 価格 | 無料（広告なし、アプリ内課金なし） |
| 配信地域 | ヨーロッパ全体と中国本土を除くすべての国と地域（香港・マカオ・台湾は含める）。App Store Connect の 配信 › 価格および配信状況 › 配信状況 で選ぶ。あとから変えても審査は要らない |
| EU のトレーダー申告（DSA） | 1.0 では申告せず、ヨーロッパに配信しない。申告が要るのは EU 27 か国だけだが、まとめてヨーロッパ全体を外した。EU に出すときは、App Store Connect の「ビジネス」で本人が判断して申告してから国を足す。トレーダーと申告すると、住所・電話番号・メールが EU のストアに表示される |
| 中国本土 | 配信しない。中国本土のストアはアプリの ICP 備案番号を求めるため |
| 輸出コンプライアンス | 暗号化を使用しない（Info.plist に `ITSAppUsesNonExemptEncryption = NO` を設定済み） |

---

## 3. 説明文

> **Guideline 2.3 / 5.2.1 への注意**: Slack、Teams、LINE、ChatGPT、Claude などの**他社の名称は、説明文・キーワード・スクリーンショットに入れない**。「チャットアプリ」「AI ツール」などの一般名称を使う。

### 日本語
```
改行したくて押した Return や、日本語の変換を確定する Return で、書きかけのメッセージを送ってしまったことはありませんか？

FloatDraft は、ショートカット一つでマウスポインタのそばに開く、小さな下書きパネルです。ここでは Return は常に改行。何度改行しても、変換を確定・取り消ししても、何かが送信されることはありません。書き終えたら ⌘Return でコピー。元のアプリに戻るので、⌘V で貼り付けるだけです。

■ 誤送信を防ぐ設計
・Return は常に改行。送信操作がないので、何度改行しても送られません
・改行のための組み合わせキー（Shift＋Return など）を覚える必要はありません
・日本語の変換中は、Return・Esc・⌘Return を入力メソッドだけが受け取ります
・⌘Return で「コピーして消去」し、元のアプリに自動で戻ります

■ どこでもすぐに
・⌃⇧Space（変更可能）で、どのアプリからでも開けます
・マウスポインタの近く、または自分で決めた定位置に開きます
・フルスクリーンのアプリの上にも表示できます

■ 送る前に整える
・行の引用（> を付ける／外す）
・コードブロックで囲む
・行末のスペースと余分な空行を整理
・どの整形も ⌘Z で元に戻せます
・文字数・空白を除いた文字数・行数をリアルタイムに表示

■ 履歴
・「コピーして消去」した下書きを最新 30 件まで保存。検索・ピン留め・復元ができます
・直前のテキストをワンクリックで再コピー

■ Mac との連携
・サービスメニュー「FloatDraft で編集」: 他のアプリで選択したテキストを下書きに取り込めます
・ショートカット App: 「下書きパネルを開く」「テキストを下書きに追加」「直前にコピーしたテキストを取得」

■ プライバシー
・データはすべてこのMacの中だけに保存されます。通信は一切しません
・アクセシビリティ権限や入力監視の権限は不要です

メニューバーに常駐し、Dock を占有しません。ログイン時の自動起動も選べます。
```

### English
```
Ever sent a half-written message because Return — pressed for a new line, or to confirm your input method — also hit "Send"?

FloatDraft is a small draft panel that opens next to your pointer with one shortcut. In it, Return always adds a new line: add as many as you like, confirm or cancel an input-method conversion, and nothing is ever sent. When you're done, press ⌘Return to copy the draft — FloatDraft takes you back to your app so you can paste with ⌘V.

SAFE BY DESIGN
• Return is always a line break — there is no send, however many lines you add
• No need to remember which modifier makes a new line (Shift-Return and the like)
• While an input method is composing text, Return, Esc and ⌘Return go to the input method only
• ⌘Return copies and clears the draft and returns you to the previous app

ALWAYS AT HAND
• ⌃⇧Space (customizable) opens it from any app
• Opens next to the pointer, or at a spot you choose
• Works over full-screen apps

TIDY BEFORE YOU SEND
• Quote lines (add or remove "> ")
• Wrap in a code block
• Remove trailing spaces and extra blank lines
• Every edit can be undone with ⌘Z
• Live character, non-space and line counts

HISTORY
• Keeps your last 30 sent drafts, with search, pinning and one-click restore
• Re-copy the last text with one click

WORKS WITH YOUR MAC
• Services menu: "Edit in FloatDraft" brings text selected in another app into your draft
• Shortcuts: Open Draft Panel, Add Text to Draft, Get Last Copied Text

PRIVATE
• Everything stays on your Mac. No network access at all
• No Accessibility or Input Monitoring permission required

Lives in the menu bar, not the Dock. Optional launch at login.
```

### キーワード（100 文字以内、カンマ区切り）
- ja: `下書き,誤送信,日本語入力,IME,メモ,チャット,改行,クリップボード,テキスト,エディタ`
- en: `draft,scratchpad,newline,IME,Japanese,input,chat,clipboard,text,editor,notes`

### プロモーションテキスト（任意、170字以内）
- ja: `改行のつもりでも、変換の確定でも、送信してしまう事故をもう起こさない。書いてから、送る。`
- en: `No more half-written messages sent by a Return meant for a new line or for confirming Japanese input. Write first, then send.`

---

## 4. App のプライバシー（App Store Connect の「App のプライバシー」）

- **データの収集: 「データを収集しない」**
  - 下書き・履歴・設定はすべて端末内（サンドボックス内の UserDefaults と Application Support）に保存し、外部に送信しない
  - ネットワークの権限（entitlement）自体を持たない
- プライバシーマニフェスト（`PrivacyInfo.xcprivacy`）: トラッキングなし、収集データなし、UserDefaults の利用理由 `CA92.1`

---

## 5. 審査メモ（App Review Information › Notes）

> 審査担当者がメニューバーアプリの UI を見つけられずにリジェクトされる（Guideline 2.1）ことを防ぐため、手順を具体的に書く。

```
FloatDraft is a menu bar app (no Dock icon). On first launch a "Welcome to FloatDraft" window explains how it works.

How to test:
1. Open any app with a text field (e.g. TextEdit or Notes) and place the cursor in it.
2. Press Control-Shift-Space (or click the pencil icon in the menu bar). A small draft panel opens next to the mouse pointer.
3. Type a few lines. Return inserts a line break; it never sends or copies anything. (In many chat apps Return sends the message, so a Return meant for a new line sends a half-written message. Preventing that is the app's core purpose.)
   With a Japanese input method: confirming a conversion with Return, or cancelling it with Esc, does not close the panel or copy text either.
4. Press Command-Return. The text is copied to the clipboard, the panel closes and focus returns to the previous app. Press Command-V to paste.
5. Other features: header buttons for quote / code block / tidy whitespace (all undoable with Command-Z), History (clock icon or Command-Y) with search and pinning, the slider icon for background opacity and pinning the panel.
6. Services menu: select text in TextEdit, then choose TextEdit › Services › Edit in FloatDraft. The panel opens with the text added to the draft (undo with Command-Z). The service only receives the text the user sends; FloatDraft never reads the general clipboard.
7. Shortcuts app: search for "FloatDraft" to find Open Draft Panel, Add Text to Draft and Get Last Copied Text (returns the last text sent with Command-Return, from FloatDraft's own history).
8. Right-click the menu bar icon for Settings (shortcut recorder, launch at login), the welcome guide and Quit.

FloatDraft does not use the network, Accessibility or Input Monitoring permissions. The global shortcut uses the standard Carbon hot key API. All data stays on the device.
```

---

## 6. スクリーンショット（2880×1800、16:10）

```bash
scripts/verify.sh --quick              # スクリプトが起動する Debug 版を作る
swift scripts/make-screenshots.swift   # build/screenshots/{ja,en}/1〜6-*.png
```
Debug 版だけにある `-screenshotScene` フック（`ScreenshotDemo.swift`）で場面を作り、パネルと、後ろに置く架空のチャットアプリのウィンドウを `screencapture -l` で撮る。それを、壁紙・メニューバー・ポインタの上に実寸（1440×900 の Retina 画面と同じ縮尺）で並べ、見出しを付ける。メニューバーとポインタは描いたもので、後ろのウィンドウは実在のアプリや製品を写さない。

壁紙は macOS に入っている「iMac Orange」（`/System/Library/Desktop Pictures/iMac Orange.heic`）を、アプリアイコンと Paper テーマの暖色に合わせて少しアプリコット寄りに回し、彩度を下げて白く薄めて使う（ダークの場面は暗くする）。差し替えや調整は `WALLPAPER=<画像> WALLPAPER_MUTE=<0〜1> WALLPAPER_HUE=<度>` を付けて実行する（標準は MUTE 0.6、HUE 8）。見出しはセミボールド、説明は標準の太さで、文字に光や影は付けない。日本語は字送りを少し広げる（見出し +5、説明 +2.5）。読みやすさは、見出しの後ろにうっすら敷いた明るい光で確保する。後ろのウィンドウは少しぼかして暗くし、パネルには強めの影を付けて、どれがこのアプリかがひと目で分かるようにしている。下書き・履歴・設定・クリップボードは使い捨てのものを使うので、実際のデータには触れない。デモはパネルを開いておくためにアプリを前面に出すので、実行中はキーボードとマウスに触らない。

| # | 場面 | 見出し（ja） |
|---|---|---|
| 1 | `open` 開いたばかりのパネルと ⌃⇧Space のキー | ⌃⇧Space で、すぐ下書き |
| 2 | `compose` 日本語を変換中（下線あり） | Return は改行。送信されません |
| 3 | `copied` パネルが閉じ、コピー完了の表示だけ | ⌘Return でコピー、⌘V で貼るだけ |
| 4 | `tidy` 引用とコードブロック | 送る前に、整える |
| 5 | `history` 履歴サイドバー（ピン留め） | 送った下書きは、履歴から呼び戻せる |
| 6 | `themes` クイック設定（ダーク、インディゴ） | 好みの見た目で |

書き出す PNG はアルファチャンネルなしの sRGB（App Store Connect はアルファ入りの画像を受け付けない）。メニューバーの日付（木曜）、メモの定例（翌日の金曜）、チャットの発言と下書きの中身は、6 枚を通して話がつながるようにしてある。

Dock は描かない（FloatDraft は Dock にアイコンを出さないアプリで、ほかのアプリのアイコンも載せられないため）。
説明文と同じく、他社の名称やロゴは入れない。

---

## 7. 既知の注意点

- **アイコン**は Icon Composer 形式の `FloatDraft/Resources/AppIcon.icon` で、`scripts/make-app-icon.swift` が書き出す（他のアプリの大きなウィンドウの上に、鉛筆で書き込み中の小さな下書きパネルが浮かぶ図柄。配色は Paper テーマとそのコーラル）。Liquid Glass の各表示（通常・ダーク・色付き・クリア）と、macOS 14〜15 用の平面のアイコンは Xcode がここから作る。変えるときはスクリプトを直して `swift scripts/make-app-icon.swift` で実行し、`AppIcon.icon` を直接編集しない。見た目の確認は Icon Composer で開くか、`ictool`（Icon Composer.app/Contents/Executables）で書き出す
- **ログイン時起動**は /Applications に置いたビルドで動作確認する（DerivedData のビルドでは登録が不安定なことがある）
- **4.2 対策の強化**: サービスメニュー「FloatDraft で編集」と App Intents（ショートカット.app）を実装済み。サービスは初回、システム設定 › キーボード › キーボードショートカット › サービス で有効になっているか確認する（/Applications に置いたビルドで確認）
- **ITMS-90284（リソース束の署名）**: 1.0.0 のビルド 1 は、KeyboardShortcuts のリソース束（`KeyboardShortcuts_KeyboardShortcuts.bundle`）が Apple Development の署名のまま残り、App Store Connect で却下された（書き出しはアプリ本体だけを Apple Distribution で署名し直し、束はそのままにする）。`project.yml` のビルド後スクリプトで束の署名を外し、アプリ本体の署名が束のファイルを含めて守る形にした。verify.sh が、署名付きの束が残っていないかを確かめる。Swift Package を足したら、その束も外す対象に入れる
- **署名**: `project.yml` はローカル用のアドホック署名（`CODE_SIGN_IDENTITY = "-"`）のまま。App Store 用は `scripts/archive.sh` がコマンドラインで自動署名とチーム ID を上書きする。Release では `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO`（get-task-allow を含めない）
