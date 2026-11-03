# CLAUDE.md — FloatDraft

macOS メニューバー常駐型の下書きポップアップ。IME の確定 Enter による誤送信を防ぐ。Mac App Store での公開が前提。

## 文書
- **仕様**: [docs/SPEC.md](docs/SPEC.md)（§0「Phase 0 合意事項」が本文より優先）
- **テスト方針、手動チェックリスト、動作確認の手段**: [docs/TESTING.md](docs/TESTING.md)
- **App Store 提出資料（説明文・審査メモ・手順・署名）**: [docs/APP_STORE.md](docs/APP_STORE.md)、[docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md)

## 進め方（ユーザーとの合意）
- マイルストーン（M1〜M5）ごとに実装し、`scripts/verify.sh` が全項目パスしたら結果を報告して**ユーザーの確認を待つ**。次のマイルストーンに勝手に進まない
- 仕様の解釈に迷ったら実装前に確認する。SPEC の §0 を変える判断は必ずユーザーの承認を得る
- `TEAM_ID=<ID> scripts/archive.sh` は Apple のサーバーと通信するので、実行前にユーザーに確認する

現状: M1〜M5 と追加機能は実装済み（[SPEC §4](docs/SPEC.md)）。1.0.0 を Mac App Store で公開済み。

## コマンド
```bash
xcodegen generate             # project.yml を変えたら必ず実行（.xcodeproj は直接編集しない）
scripts/verify.sh --quick     # 開発中: 生成、Debug ビルド、テスト
scripts/verify.sh             # 完了条件: 全項目（内容は docs/TESTING.md）
scripts/sync-strings.sh       # UI 文字列を追加・変更したら実行し、増えたキーに日本語訳を付ける
open build/DerivedData/Build/Products/Debug/FloatDraft.app   # 手動確認
```
ビルドログは `build/logs/`、DerivedData は `build/DerivedData`。

## 構成
`FloatDraft/` 配下に置いたファイルは自動でターゲットに含まれる（追加したら `xcodegen generate`）。
```
project.yml                  # XcodeGen 定義（唯一の正。.xcodeproj は生成物だが git に含める）
FloatDraft/Sources/
  App/                       # 起動、非表示の MainMenu、メニューバー項目、ScreenshotDemo（Debug のみ）
  Panel/                     # パネルと表示制御（PanelController）、配置などの純粋ロジック、テーマ、
                             # ヘッダーとステータスバー、クイック設定、Clipboard（唯一のクリップボード書き込み口）
  Editor/                    # DraftTextView（IME ガード）、EditorController、下書きの保存、整形・文字数の純粋ロジック
  History/                   # 履歴（JSON、30件＋ピン留め）、サイドバー、検索欄
  Settings/                  # 設定、オンボーディング、ログイン時起動
  Integrations/              # サービスメニュー（ServicesProvider）、App Intents
  Shortcuts/                 # KeyboardShortcuts.Name の定義
FloatDraft/Support/          # Info.plist と entitlements
FloatDraft/Resources/        # アイコン（AppIcon.icon は make-app-icon.swift の生成物）、翻訳、PrivacyInfo、
                             # Credits.rtf（「FloatDraft について」に出るライセンス表記）
FloatDraftTests/             # Swift Testing（アプリをホストにして実行）
scripts/                     # verify.sh（検証ゲート）、archive.sh など
```

## 絶対に守るルール

### App Store と全体
- **禁止 API**: アクセシビリティ（`AXIsProcessTrusted`、`AXUIElement*`）、イベントタップ（`CGEvent.tapCreate`、`CGEventPost`）、入力監視（`IOHIDRequestAccess`）、`NSEvent.addGlobalMonitorForEvents`。verify.sh が検出する
- **Entitlements は `com.apple.security.app-sandbox` だけ**。ネットワーク、ファイル、Apple Events などを追加しない
- **クリップボードは書き込み専用**（`clearContents` と `setString`）。プログラムから読まない。唯一の例外は `ServicesProvider.swift` で、サービスの要求でシステムから渡された専用のペーストボードだけを読む（`NSPasteboard.general` は開かない）。verify.sh がこの範囲を強制する
- **ライフサイクル**: SwiftUI の `App`、`MenuBarExtra`、`Settings` シーンは使わない（mainMenu が上書きされるため）。SwiftUI は NSHostingView 経由で View にだけ使う
- ログイン時起動の既定値は OFF

### エディタとテキスト入力
- **IME ガード**: NSTextView の `keyDown`、`doCommand(by:)`、`performKeyEquivalent` の先頭で `hasMarkedText()` を判定する。true なら super に渡すだけにする。⌘Return と Esc を NSTextView の外（SwiftUI の `.keyboardShortcut`、`.onExitCommand`、メニューのキー割り当て）で扱わない
- **テキストの書き換え**は `shouldChangeText(in:replacementString:)` → `textStorage` の置換 → `didChangeText()` で行う。`textView.string = ...` は初期化のときだけ使う
- **エディタは SwiftUI に埋め込まない**: NSScrollView と DraftTextView は AppKit の Auto Layout でパネルに直接配置する。SwiftUI（NSHostingView）はヘッダー、ステータスバー、今後のオーバーレイにだけ使う（初回表示時の First Responder と E6 を確実にするため）
- **パネル内の検索欄など新しいテキスト入力**でも、Esc と Return は `hasMarkedText()` を確認してから扱う（`HistorySearchField` のやり方に合わせる）
- **外部から届くテキスト**（サービスメニュー、ショートカット）は `PanelController.addExternalText(_:showingPanel:)` 経由で追加する。変換中は拒否し、1回の Undo で戻せる形で入れる

### パネルと UI
- **フォーカス**: resignKey では元のアプリを再アクティブ化しない（D1）。`activate(ignoringOtherApps:)` は非推奨なので使わない
- **透過と配色**: `panel.alphaValue` は使わず、背景レイヤー（`PanelController.backgroundView`：ぼかし＋`ThemeBackgroundView`）の不透明度だけを変える。色はハードコードせず `PanelPalette`（`PanelTheme.palette`）から取る。SwiftUI 側は背景を描かない（帯の背景は `ThemeBackgroundView` が描く）
- **オーバーレイ**（現在はクイック設定のみ）は `PanelController.setOverlay(_:)` で、**履歴サイドバー**は `setHistorySidebarVisible(_:)` でだけ切り替える。エディタは隠すだけで階層から外さず、隠れたエディタに First Responder を残さない（入力が見えない場所に入るため）。変換中は開かない
- **パネル内のツールチップは `.hoverTooltip(...)`** を使う。`.help(...)` はアクティブなアプリでしか表示されず、パネルでは出ない（verify.sh が検出する）。設定ウィンドウなど通常のウィンドウでは `.help` でよい

## コード規約
- Swift 6 言語モード。デフォルトのアクター分離は MainActor（`project.yml` で設定済み）
- 警告は 0 件（Swift と Clang の警告はエラー扱い）。非推奨 API の警告も直す
- UI に依存しないロジック（配置計算、整形、カウント、履歴）は純粋な型として切り出し、ユニットテストを付ける
- テストでは `TestEnvironment`（`FloatDraftTests/TestSupport`）で UserDefaults とクリップボードを隔離する。実ユーザーのクリップボードに触れない
- UI の文字列は英語をキーにする（`String(localized:)` または SwiftUI の文字列リテラル）。日本語訳は `FloatDraft/Resources/Localizable.xcstrings` に入れる。訳がないと verify.sh が失敗する
- App Shortcut の呼び出しフレーズの日本語訳は `AppShortcuts.xcstrings` に入れる（こちらも訳がないと verify.sh が失敗する）
- メニューやウィンドウはタイトルで探さない（ローカライズで変わる）。テストではアクションや中身で探す
- `#available` で分岐するのは macOS 14 より新しい API だけ

## 既知の落とし穴
- **ビルドした FloatDraft を起動したままテストすると、xcodebuild が終わらなくなる**（同じバンドル ID のテスト用ホストとぶつかる）。`scripts/verify.sh` はテスト前に `build/DerivedData` 内のコピーを終了させる。xcodebuild を直接使うときも、先に終了させること
- **Swift Package を足したら**、そのライセンスを `FloatDraft/Resources/Credits.rtf` と `THIRD_PARTY_NOTICES.md` に足す
- テスト実行時の `com.apple.linkd.autoShortcut` 接続エラーのログは無視してよい（サンドボックス環境で出るシステムログ）
