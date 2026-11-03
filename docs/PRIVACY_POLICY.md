# FloatDraft プライバシーポリシー / Privacy Policy（下書き）

> **公開しているのは https://efukan.jp/privacy の「第2部 各則7」**（正本は別リポジトリ efukan-pages の `privacy.html`）。
> ここはその下書きと英語版の控え。保存するもの・権限・連携の機能を変えたら、先に efukan-pages 側を直し、ここも合わせる。
> 英語版は今のところどこにも掲載していない（サイトは日本語のみ）。

最終更新日 / Last updated: 2026-10-25

## 日本語

FloatDraft（以下「本アプリ」）は、利用者の個人情報を収集しません。

- **収集する情報**: ありません。本アプリは開発者や第三者のサーバーと一切通信しません（ネットワークを利用する権限自体を持っていません）。アカウント登録も不要です。
- **端末内に保存する情報**: 書きかけの下書きとカーソルの位置、「コピーして消去」した下書きの履歴（新しいものから 30 件とピン留めした項目）、表示位置・大きさ・不透明度・テーマ・ショートカットキーなどの設定。これらは本アプリ専用の領域（macOS のサンドボックス内）にのみ保存され、端末の外に送信されることはありません。履歴は本アプリ内で 1 件ずつ、またはピン留め以外をまとめて削除できます。
- **アプリを削除したとき**: macOS では、アプリ本体を削除しても、上記のデータは Mac の中（`~/Library/Containers/jp.efukan.FloatDraft`）に残ります。データも消すときは、Finder でこのフォルダをゴミ箱に入れてください。
- **バックアップ**: Time Machine などで Mac をバックアップしている場合、上記のデータもバックアップに含まれます。開発者がバックアップを受け取ることはありません。
- **クリップボード**: 利用者が「コピーして消去」「コピー」「再コピー」を実行したときにのみ、クリップボードへテキストを書き込みます。本アプリがクリップボードの内容を読み取ることはありません。
- **ほかのアプリとの連携**: サービスメニューの「FloatDraft で編集」では、利用者がそのとき選んだ文字だけを macOS から受け取ります。ショートカット App の「テキストを下書きに追加」で渡された文字も下書きに加えます。「直前にコピーしたテキストを取得」を実行したときに限り、最後に「コピーして消去」した文字をそのショートカットへ渡します。
- **ログイン時の起動**: 設定で有効にした場合に限り、macOS のログイン項目に登録します（初期設定は無効）。
- **解析・広告・トラッキング**: 行いません。
- **権限**: アクセシビリティ・入力監視・ネットワーク・ファイルなどの権限は使用しません。

お問い合わせ: X（[@efukandev](https://x.com/efukandev)）または GitHub（[github.com/efukan](https://github.com/efukan)）

## English

FloatDraft ("the app") does not collect any personal information.

- **Data collected**: None. The app never communicates with the developer's or any third party's servers (it does not even have permission to use the network). No account is needed.
- **Data stored on your Mac**: your unfinished draft and cursor position, the history of drafts you sent with Copy & Clear (the latest 30 plus any you pin), and settings such as position, size, opacity, theme and the keyboard shortcut. These are stored only in the app's own sandboxed container and never leave your Mac. You can delete history items one by one, or everything that is not pinned, in the app.
- **When you delete the app**: on macOS, deleting the app does not delete this data; it stays in `~/Library/Containers/jp.efukan.FloatDraft`. To remove it too, move that folder to the Trash in the Finder.
- **Backups**: if you back up your Mac (for example with Time Machine), the data is included in your backup. The developer never receives your backups.
- **Clipboard**: the app writes text to the clipboard only when you choose Copy & Clear, Copy or Re-copy. It never reads the clipboard.
- **Other apps**: with the Services menu item "Edit in FloatDraft", the app receives only the text you selected at that moment. Text passed by the Shortcuts action "Add Text to Draft" is added to the draft. Only when you run "Get Last Copied Text" does the app hand the text you last sent with Copy & Clear to that shortcut.
- **Launch at login**: the app registers itself as a login item only if you turn this on in Settings (off by default).
- **Analytics, advertising, tracking**: None.
- **Permissions**: the app does not use Accessibility, Input Monitoring, network, file or similar permissions.

Contact: X ([@efukandev](https://x.com/efukandev)) or GitHub ([github.com/efukan](https://github.com/efukan))
