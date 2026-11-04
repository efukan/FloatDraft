# FloatDraft 仕様書

macOS 向けメニューバー常駐型の下書きポップアップ。チャットアプリや AI ツールで「日本語変換確定の Enter」と「送信の Enter」の押し間違いによる誤送信を防ぐ。ショートカット 1 つでマウスカーソル周辺（またはドラッグして決めた定位置）に最前面エディタを呼び出し、整形してからクリップボードへコピーし、元のアプリへフォーカスを戻す（ペーストはユーザーが ⌘V で行う）。

Mac App Store で公開し、Guideline 4.2 を通過することを前提とする。

> **優先順位**: §0「Phase 0 合意事項」は §1 以降の本文より優先する。本文と矛盾する場合は §0 に従う。

---

## 0. Phase 0 合意事項（2026-10-23 承認）

### 決定事項
| ID | 決定 |
|---|---|
| D1 | `windowDidResignKey`（パネル外クリック）では `orderOut` のみ。`previousApp` の再アクティブ化は **Esc と Copy & Clear のときだけ**行う。**例外（2026-10-25 追加）**: 操作スペースの切り替え（スワイプ、⌃← / ⌃→）で key が外れたときは閉じず、パネルを key に戻す（アプリはアクティブ化しない）。設定「操作スペースを切り替えてもパネルを閉じない」（既定 ON）でオフにできる |
| D2 | ⌘Return と Esc は **NSTextView サブクラスの中だけ**で処理する。Copy & Clear ボタンに `.keyboardShortcut` を付けない。`.onExitCommand` と `.cancelAction` も使わない |
| D3 | XcodeGen（`project.yml` を正とする）。生成した `.xcodeproj` も git に含める |
| D4 | AppKit ライフサイクル（`main.swift` と `AppDelegate`）。SwiftUI は NSHostingView 経由で View にだけ使う。Edit メニューは二段構え（非表示の mainMenu ＋ パネルの `performKeyEquivalent` から mainMenu への明示的な転送） |
| D5 | ホットキーの Recorder とログイン時起動の設定は**独立した設定ウィンドウ**（NSWindow + NSHostingController）に置く。ログイン時起動の**既定値は OFF** |
| D6 | 空行の整理は改行 3 個以上を改行 2 個にする（`\n{3,}` → `\n\n`、つまり空行を最大 1 行にする） |
| D7 | 履歴は Application Support に JSON で保存する。ピン留めは 30 件の上限に含めない。クリアと履歴からの復元は Undo できるように置き換える |
| D8 | マイルストーンは M1〜M5 とし、初回起動時のオンボーディングを追加する |

### 仕様の補正
- **C3 フォーカス復帰**: nonactivating パネルでは元のアプリはアクティブなまま。`orderOut` で自然に戻るのが基本。FloatDraft がアクティブになった後（設定ウィンドウなど）は、`NSApp.yieldActivation(to:)` を呼んでから `activate(from:options:)` で戻す。`activate(ignoringOtherApps:)` は非推奨なので使わない
- **C4 クランプ対象の画面**: ドラッグ位置記憶モードでは「保存したフレームと最も重なる画面」を基準にする。その画面がない場合はマウスのある画面にする。マウス追従モードではマウスのある画面を基準にし、まず上側への反転を試し、それでもはみ出せばクランプする
- **E1** NSTextView の Esc（`cancelOperation:` → `complete:`）は `doCommand(by:)` で横取りする
- **E2** `isMovableByWindowBackground = false`。ヘッダーとステータスバーに `window.performDrag(with:)` を呼ぶドラッグハンドル View を置く
- **E3** プログラムからの移動はフラグで除外し、ユーザーのドラッグだけを位置として保存する
- **E4** トグルの状態遷移: 表示中かつ key → 閉じる。表示中で key でない → 前面に出して key にする。非表示 → 開く。ステータスアイコンをクリックした直後に再オープンしないよう、時間差で判定する
- **E5** `previousApp` は `NSWorkspace.didActivateApplicationNotification` で「自分以外で最後にアクティブになったアプリ」に更新し続ける
- **E6** NSTextView は AppKit 側のコントローラが所有する。オーバーレイ（履歴など）は ZStack で上に重ね、エディタを階層から外さない
- **E8** インライン予測（`inlinePredictionType`）、Writing Tools、数式補完、`smartInsertDeleteEnabled`、リンク検出、データ検出を無効にする（OS のバージョンに応じて `#available` で分岐）
- **E9** `hasMarkedText()` が true の間は、整形、Copy & Clear、履歴からの復元を実行しない（メニュー項目は `validateMenuItem` で無効にする）
- **E12** 行末スペースの削除はコードフェンスの中も含めて行う（Markdown の行末スペース 2 つによる改行は失われる。ツールチップでその旨を示す）
- **E13** コードを囲むフェンスは、中にある最長のバッククォート列より 1 つ長くする（最低 3 個）
- **E16** 文字数は書記素クラスタ（`String.count`）で数える。空白除外は `.whitespacesAndNewlines`（全角スペースを含む）で判定する
- **E17**（M4 で訂正）Option だけ／Option+Shift だけのホットキーが動かないのは、macOS 15.0〜15.1 のサンドボックス環境に限ったバグ（15.2 で修正）。KeyboardShortcuts 3.x がそのバージョンでだけ登録を拒否するので、独自の検証は行わない
- **E18** クリップボードは**書き込み専用**。プログラムから読まない
- **E19** 自動ペーストはしない。コピー後に「コピーしました — ⌘V で貼り付け」と短く表示する
- **E20** 見えない文字（`InvisibleCharacters`）: タグ文字 U+E0000〜E007F（旗の絵文字の中は除く）、方向制御 U+202A〜202E・U+2066〜2069、U+200B・U+2060・U+FEFF、2 つ目以降が続く異体字セレクタ。プロンプトに指示を隠す手口（ASCII smuggling）や表示順の偽装に使われる。ZWJ・ZWNJ、絵文字や IVS の異体字セレクタ 1 つは正規の文字なので対象外。含まれているとステータスバーに件数を警告として出し、「空白を整理」で取り除く。コピー時に黙って消すことはしない

---

## 1. 技術スタック・制約条件

- アプリ名とバンドル ID: `FloatDraft` / `jp.efukan.FloatDraft`
- macOS 14.0 以上。Universal Binary（`ARCHS = $(ARCHS_STANDARD)`）
- Swift 6（言語モード 6、デフォルトのアクター分離は MainActor）。SwiftUI と AppKit の組み合わせ（NSPanel + NSTextView）
- App Sandbox を有効にする。ファイルアクセスやネットワーク通信の権限は一切要求しない
- **禁止**: アクセシビリティ権限（`AXIsProcessTrusted`、`CGEvent.tapCreate` など）と Input Monitoring 権限。グローバルなイベント監視（`addGlobalMonitorForEvents`）も使わない
- 外部パッケージ: `sindresorhus/KeyboardShortcuts`（3.x）
- `LSUIElement = YES`（Dock に出さず、メニューバーにだけ常駐する）
- エディタ内の ⌘A / C / V / X / Z / ⇧⌘Z がビープ音を鳴らさずに動くこと（D4 の二段構え）

## 2. コア仕様

### ① 呼び出し・背面アプリの記憶・ドラッグ移動・出現位置
- グローバルショートカット（初期値 `Control + Shift + Space`、変更可能）またはメニューバーアイコンでトグルする（E4）
- 背面アプリ: 表示する直前の `frontmostApplication` のうち自分以外のものを保持し、E5 で更新し続ける
- ドラッグ: ヘッダーとステータスバーをつかんで移動できる（E2）
- 出現位置モード（パネル上のトグルまたは設定で切り替える）
  1. **マウス追従**: パネルの上端をカーソルの 20pt 下に置く（`x = mouse.x - w/2`、`y = mouse.y - h - 20`）。下にはみ出す場合はカーソルの 20pt 上へ反転し、それでもはみ出せばクランプする
  2. **ドラッグ位置記憶**: ユーザーがドラッグした `frame.origin` を UserDefaults に保存する。保存がない初回はマウス追従と同じ位置に開く
  - どちらのモードでも、対象画面（C4）の `visibleFrame` 内にクランプする。パネルのサイズはモードに関係なく保存する
- NSPanel のサブクラス
  - styleMask `[.nonactivatingPanel, .titled, .fullSizeContentView, .resizable, .utilityWindow]`、level `.floating`（`.utilityWindow` は key の有無で影の大きさを変えないため。操作スペースの切り替えで一瞬 key が外れても点滅しない）
  - 信号機ボタンは隠し、タイトルバーは透明、タイトルも隠す
  - `isFloatingPanel = true`、`hidesOnDeactivate = false`
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]`
  - `canBecomeKey = true`、`canBecomeMain = false`。表示時に `makeKeyAndOrderFront` し、NSTextView を First Responder にする

### ② 入力・IME 保護
- エディタは NSTextView のサブクラスを NSViewRepresentable でラップする（E6: インスタンスはコントローラが所有する）
- `isRichText = false`、`allowsUndo = true`、`importsGraphics = false`。引用符、ダッシュ、テキスト置換、スペル自動修正の自動処理は OFF にし、E8 も適用する
- **IME 保護（最重要）**: `keyDown`、`doCommand(by:)`、`performKeyEquivalent` の先頭で `hasMarkedText()` を判定する。true の間は Return、⌘Return、Esc を含むすべてのキーを super に渡し、パネル側の処理は一切発火させない
- 確定状態でのキー
  - Return: 改行
  - ⌘Return（または Copy & Clear ボタン）: 前後の空白を除いて空なら何もしない。空でなければ全文をクリップボードへ書き込み → 履歴と「直前コピー」に保存 → Undo できる形でクリア → `orderOut` → フォーカス復帰（C3）
  - Esc: テキストと `selectedRange` を保存したまま `orderOut` → フォーカス復帰（C3）
  - resignKey（ピン留め OFF のとき）: テキストを保存して `orderOut` するだけ（D1）
    - 操作スペースの切り替えによる resignKey は閉じない（D1 の例外）。`NSWorkspace.activeSpaceDidChangeNotification` と resignKey は順不同で届くので、互いに 0.5 秒以内なら切り替えとみなす（`PanelAutoHide`）。マウスボタンが押されたままの resignKey はクリックなので即座に閉じ、それ以外（⌘Tab など）は 0.5 秒待って切り替えが来なければ閉じる。key を取り戻すのは resignKey のコールバックを抜けた直後（コールバック内で `makeKey` すると macOS に打ち消され、見えているのにキーが届かないパネルになる）
- 下書きは、非表示にするとき、アプリ終了時、入力が止まってから一定時間後に保存する

## 3. 差別化機能（Guideline 4.2 対策）
1. **ステータスバー**: 文字数、空白除外文字数、行数（E16）。見えない文字があるときだけ、その件数の警告（クリックで「空白を整理」、E20）。直前に Copy & Clear したテキストをもう一度コピーできる「Re-copy last」ボタン
2. **クイック整形**（Undo 対応。`shouldChangeText` → 置換 → `didChangeText`。ボタンを押した後は First Responder をエディタに戻す。E9）
   - 引用トグル（⌘⇧.）: 選択範囲の行（未選択なら全文）の行頭に `> ` を付ける。すべての行に付いていれば外す
   - コードブロック（⌘⇧K）: 選択範囲（未選択なら全文）をフェンスで囲む（E13）
   - 空白・空行整理: 見えない文字（E20）と行末スペースを削除し、空行を圧縮する（D6、E12）
   - 改行コード: 貼り付けたテキストの CRLF、CR、U+2028、U+2029 は、そのまま下書きに残り、そのままコピーされる。3 つの整形は、対象の行でこれらを `\n` に揃えてから処理する
3. **履歴**: Copy & Clear したものを最大 30 件保存する（ピン留めは上限外、D7）。ピン留めを外した項目は「最近」の先頭に移る（古い順の位置に戻すと、上限を超えてその場で消えるため。上限を超えた分は「最近」の一番古い項目が消える）。履歴ファイルを読めないときは、上書きせず同じフォルダの `history.unreadable-<UUID>.json` に移して空の履歴で始める（中身を取り出せる余地を残す。アプリからは消せない）。キーワード検索、クリックでの復元（Undo 可）、ピン留めができる。**エディタの右側にサイドバーとして並べる**（別ウィンドウや popover は使わない）。開くとパネルが 240pt 広がり、エディタは見えたまま。開閉状態は保存する。「ピン留め以外を消去」はサイドバー下部でその場で確認してから削除する。1 件ずつの削除でも「ピン留め以外を消去」でも、Re-copy 用の直前のテキスト（`lastCopiedText`）を持つ項目が履歴からなくなったら、それも消す（ピン留めに同じテキストが残る場合は残す。消したはずの文字が再コピーやショートカットで取り出せないように）（シートやアラートはパネルからフォーカスを奪って閉じてしまうため使わない）。⌘Y / 時計アイコンで開閉し、開くと検索欄にフォーカスが移る（変換中は開かない）。検索欄の Esc はエディタへ戻る
4. **ウィンドウ制御**
   - ピン留め: ON の間は resignKey で閉じない
   - 背景の不透明度: 50〜100%。**背景レイヤーだけを変え、文字は 100% のまま**にする（`panel.alphaValue` は使わない）
   - 表示モード（設定ウィンドウ）: 端末に合わせる（既定）／ライト／ダーク。`NSApp.appearance` でアプリ全体に適用する
   - テーマ: ペーパー（既定）、オーシャン、インディゴ、グラファイト（常に暗色）、ガラス（従来の半透明）。グラファイト以外はライト／ダークに追従する。色は `PanelTheme` / `PanelPalette` に集約し、背景は `ThemeBackgroundView` がまとめて描く
   - 設定ウィンドウ（D5）: ホットキーの Recorder（E17）、ログイン時起動（`SMAppService.mainApp`、既定 OFF）、出現位置モード
  - パネル内のクイック設定オーバーレイ: テーマ、出現位置モード、ピン留め、背景の不透明度（ライブで確認できるようパネル内に置く）
5. **オンボーディング**（D8）: 初回起動時にショートカットの説明と「パネルを試す」ボタンを出す（審査担当者が UI を見つけられないことへの対策）
5a. **使い勝手の改善**（追加機能）
   - ⌥⌘Return / ステータスバーのボタン: 消去せず、パネルも閉じずにコピーする（履歴にも残す）。⌘Return と同じく NSTextView 内だけで扱う（D2）
   - 空のエディタには操作ヒント（「Return で改行 · ⌘Return でコピーして消去」）を薄く表示する
   - 履歴: 検索欄で ↑↓ で選択、Return で置換、⌥Return でカーソル位置に挿入。行のクリックは置換、⌥クリックは挿入（どちらも Undo 可）。⌘1〜⌘9 で上から N 番目のピン留めを挿入（変換中は無効）
   - 文字サイズ ⌘+ / ⌘− / ⌘0（10〜28pt）と等幅フォントの切り替え（設定ウィンドウ）
   - アイコンだけのボタンには VoiceOver 用のラベルを付ける
6. **サービスメニュー「Edit in FloatDraft」**（追加機能）: 他のアプリで選択したテキストを下書きに追加し、パネルを開く
   - Info.plist の `NSServices`。テキスト（`public.utf8-plain-text`）を受け取るだけで、送り返さない（`NSReturnTypes` なし）
   - 下書きが空白だけなら置き換え、それ以外は改行して末尾に追加する（書きかけを失わない）。1回の Undo で元に戻せる。変換中は追加せず、パネルだけ開く（E9）
   - 読んでよいのはシステムから渡された専用のペーストボードだけ（E18 の唯一の例外。一般クリップボードは読まない）
7. **App Intents（ショートカット.app）**（追加機能）: 「下書きパネルを開く」「下書きにテキストを追加」「直前にコピーしたテキストを取得」の3アクションと、日本語の呼び出しフレーズ
   - 「直前にコピーしたテキスト」は履歴の `lastCopiedText` を返す（クリップボードは読まない）
   - テキストの追加はサービスメニューと同じ経路（`PanelController.addExternalText`）で、同じく変換中は拒否する

## 4. マイルストーン
| M | 状態 | 内容 |
|---|---|---|
| M1 | ✅ 完了 | 環境構築（XcodeGen、テスト用ターゲット、`scripts/verify.sh`、CLAUDE.md） |
| M2 | ✅ 完了 | パネル、ホットキー、出現位置モード 2 種、クランプ、ドラッグハンドル、Edit メニューの二段構え、トグルの状態遷移 |
| M3 | ✅ 完了 | IME ガード付きの NSTextView、⌘Return / Esc、フォーカス復帰、下書きの永続化 |
| M4 | ✅ 完了 | 整形、履歴、カウンター、再コピー、不透明度、ログイン時起動、設定ウィンドウ、オンボーディング |
| M5 | ✅ 完了（1.0.0 を Mac App Store で公開済み） | アイコン、ローカライズ、Archive と書き出し、審査メモ |
| 追加 | ✅ 完了 | サービスメニュー「Edit in FloatDraft」、App Intents（ショートカット.app のアクション3つ） |
