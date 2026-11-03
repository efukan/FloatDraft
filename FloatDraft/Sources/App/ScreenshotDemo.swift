#if DEBUG
import AppKit
import SwiftUI

/// Stages the panel for App Store screenshots: `FloatDraft -screenshotScene open|compose|tidy|history|copied|themes`
/// (with `-AppleLanguages '(en)'` for the English set). `scripts/make-screenshots.swift` launches each scene,
/// captures the windows and composites them onto a drawn desktop.
/// Behind the panel sit made-up app windows (`MockChatView`, `MockNotesView`), so the panel is seen where it is
/// used, without showing any real app or brand.
/// Every store is a throwaway one, so the real draft, history, settings and clipboard are never read or changed.
enum ScreenshotDemo {
    enum Scene: String {
        case open, compose, tidy, history, copied, themes
    }

    static let scene = UserDefaults.standard.string(forKey: "screenshotScene").flatMap(Scene.init)

    private static let suiteName = "FloatDraftScreenshots"
    private static var panelSize: CGSize { CGSize(width: 540, height: scene == .history ? 390 : 300) }
    private static let chatSize = CGSize(width: 960, height: 560)
    private static let notesSize = CGSize(width: 680, height: 480)
    private static var isJapanese: Bool { Bundle.main.preferredLocalizations.first == "ja" }

    static func makePanelController() -> PanelController {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let preferences = PanelPreferences(defaults: defaults)
        preferences.appearanceMode = scene == .themes ? .dark : .light
        preferences.theme = scene == .themes ? .indigo : .paper
        preferences.panelSize = panelSize
        preferences.editorFontSize = 15

        let historyURL = FileManager.default.temporaryDirectory.appending(path: "screenshot-history.json")
        try? FileManager.default.removeItem(at: historyURL)
        // Sent earlier the same morning, so the sidebar reads "1–2 hours ago".
        var clock = Date(timeIntervalSinceNow: -2.5 * 3600)
        let history = HistoryStore(fileURL: historyURL, now: { clock })
        for (text, pinned) in historySeed {
            clock += 900
            history.add(text)
            if pinned, let id = history.items.first?.id { history.togglePin(id) }
        }

        return PanelController(preferences: preferences,
                               editor: EditorController(draftStore: DraftStore(defaults: defaults)),
                               history: history,
                               pasteboard: NSPasteboard(name: NSPasteboard.Name(suiteName)))
    }

    static func stage(_ scene: Scene, in controller: PanelController) {
        let editor = controller.editor
        // Launched from a script, the demo is not the active app; the panel would close as soon as it lost key.
        NSApp.activate()
        showBackdrops()
        if scene == .copied {
            // After ⌘Return the panel is gone and only the confirmation shows, over the app being pasted into.
            let toast = CopyToast()
            let size = toast.window.contentView?.fittingSize ?? .zero
            if let screen = NSScreen.main?.visibleFrame {
                toast.window.setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2,
                                             width: size.width, height: size.height), display: true)
            }
            // Kept on screen (no fade-out) until the capture is done.
            toast.window.orderFrontRegardless()
            retained.append(toast)
            return
        }
        controller.show()
        if scene == .history {
            // Widens the panel by the sidebar; the frame below is set with that width.
            controller.setHistorySidebarVisible(true)
        }
        if let screen = NSScreen.main?.visibleFrame {
            let width = panelSize.width + (scene == .history ? PanelPreferences.historySidebarWidth : 0)
            controller.panel.setFrame(NSRect(x: screen.midX - width / 2, y: screen.midY - panelSize.height / 2,
                                             width: width, height: panelSize.height), display: true)
        }
        editor.replaceAll(with: draft(for: scene), actionName: "")

        switch scene {
        case .compose:
            if isJapanese {
                // What a Japanese input method shows before the conversion is confirmed.
                let composing = "けってい"
                editor.textView.setMarkedText(composing, selectedRange: NSRange(location: 4, length: 0),
                                              replacementRange: NSRange(location: NSNotFound, length: 0))
                // The underline an input method draws under unconfirmed text; setMarkedText alone shows none.
                editor.textView.textStorage?.addAttributes([
                    .underlineStyle: NSUnderlineStyle.thick.rawValue,
                    .underlineColor: NSColor.textColor,
                ], range: editor.textView.markedRange())
            }
        case .open, .tidy, .history, .copied:
            break
        case .themes:
            controller.setOverlay(.quickSettings)
        }
    }

    private static var retained: [AnyObject] = []

    /// A plain screen-sized window first, so the windows' translucent parts show it instead of whatever is
    /// really on the desktop; then a notes window further back, then the chat app the panel floats over:
    /// the main window, so its title bar looks active and the notes one inactive.
    private static func showBackdrops() {
        if let screen = NSScreen.main?.frame {
            let desktop = NSWindow(contentRect: screen, styleMask: .borderless, backing: .buffered, defer: false)
            // About the color of the toned-down wallpaper in make-screenshots.swift.
            desktop.backgroundColor = scene == .themes
                ? NSColor(srgbRed: 0.17, green: 0.13, blue: 0.11, alpha: 1)
                : NSColor(srgbRed: 0.93, green: 0.84, blue: 0.74, alpha: 1)
            desktop.isReleasedWhenClosed = false
            desktop.ignoresMouseEvents = true
            desktop.orderFront(nil)
            retained.append(desktop)
        }

        let notes = NSWindow(contentRect: NSRect(origin: .zero, size: notesSize),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        notes.title = isJapanese ? "打ち合わせメモ.txt" : "Meeting Notes.txt"
        notes.isReleasedWhenClosed = false
        notes.contentView = NSHostingView(rootView: MockNotesView(isJapanese: isJapanese))
        notes.center()
        notes.orderFront(nil)
        retained.append(notes)

        let chat = NSWindow(contentRect: NSRect(origin: .zero, size: chatSize),
                            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                            backing: .buffered, defer: false)
        chat.titlebarAppearsTransparent = true
        chat.titleVisibility = .hidden
        chat.isReleasedWhenClosed = false
        chat.contentView = NSHostingView(rootView: MockChatView(isJapanese: isJapanese, size: chatSize))
        chat.center()
        chat.makeKeyAndOrderFront(nil)
        retained.append(chat)
    }

    private static func draft(for scene: Scene) -> String {
        switch (scene, isJapanese) {
        case (.open, true):
            "了解です！\n議題をまとめて、"
        case (.open, false):
            "Sure!\nI'll put the agenda together and "
        case (.compose, true):
            "了解です！明日の議題です。\n\n1. 進捗の確認\n2. リリース日の"
        case (.compose, false):
            "Sure! Here's the agenda for tomorrow:\n\n1. Progress check\n2. Release date\n3. Next steps"
        case (.tidy, true):
            "> リリース日もそこで決めたいですね。\n\n賛成です。リリース前の確認はこの手順で:\n\n```\nscripts/verify.sh\nscripts/archive.sh\n```"
        case (.tidy, false):
            "> Let's settle the release date there too.\n\nAgreed. Before the release we run:\n\n```\nscripts/verify.sh\nscripts/archive.sh\n```"
        case (.history, true):
            "了解です！\n"
        case (.history, false):
            "Sure!\n"
        case (.copied, true):
            "承知しました。\n明日の 10 時からでお願いします。"
        case (.copied, false):
            "Sounds good.\nLet's meet at 10 tomorrow."
        case (.themes, true):
            "テーマと背景の不透明度は\nパネルの中ですぐに変えられます。"
        case (.themes, false):
            "Change the theme and background opacity\nright inside the panel."
        }
    }

    /// Oldest first; `true` pins the item.
    private static var historySeed: [(String, Bool)] {
        isJapanese ? [
            ("いつもお世話になっております。", true),
            ("お疲れさまです。確認しました、ありがとうございます！", false),
            ("資料を共有します。ご確認をお願いします。", false),
            ("15 時からの打ち合わせ、5 分ほど遅れます。", false),
            ("以上、よろしくお願いいたします。", true),
            ("明日の打ち合わせの件です。資料は午前中に共有します。", false),
        ] : [
            ("Thanks for getting back to me so quickly.", true),
            ("Got it, thanks!", false),
            ("Sharing the slides — let me know what you think.", false),
            ("Running about 5 minutes late for the 3 pm call.", false),
            ("Let me know if you have any questions.", true),
            ("About tomorrow's meeting: I'll share the slides in the morning.", false),
        ]
    }
}
/// A generic chat app: channel list, a few messages and the message field. No real product's look or name.
private struct MockChatView: View {
    let isJapanese: Bool
    let size: CGSize

    private struct Message: Identifiable {
        let id = UUID()
        let name: String
        let time: String
        let text: String
        let color: Color
    }

    private var channels: [String] {
        isJapanese ? ["お知らせ", "開発", "デザイン", "雑談"] : ["announcements", "dev", "design", "random"]
    }

    private var people: [String] { isJapanese ? ["佐藤", "鈴木", "田中"] : ["Alex", "Sam", "Jordan"] }

    private var messages: [Message] {
        let names = people
        return isJapanese ? [
            Message(name: names[0], time: "9:58", text: "おはようございます。明日の打ち合わせの議題をまとめてもらえますか？", color: .orange),
            Message(name: names[1], time: "10:03", text: "リリース日もそこで決めたいですね。", color: .teal),
            Message(name: names[2], time: "10:12", text: "了解です。資料は明日の午前中に共有します。", color: .indigo),
        ] : [
            Message(name: names[0], time: "9:58 AM", text: "Morning! Could you put together the agenda for tomorrow's meeting?",
                    color: .orange),
            Message(name: names[1], time: "10:03 AM", text: "Let's settle the release date there too.", color: .teal),
            Message(name: names[2], time: "10:12 AM", text: "Sure. I'll share the slides tomorrow morning.", color: .indigo),
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text("# " + channels[1])
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                Divider()
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(messages) { message in row(message) }
                }
                .padding(20)
                Spacer(minLength: 0)
                messageField
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: size.width, height: size.height)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isJapanese ? "チーム" : "Team")
                .font(.system(size: 15, weight: .bold))
                .padding(.bottom, 10)
            sectionTitle(isJapanese ? "チャンネル" : "Channels")
            ForEach(channels, id: \.self) { channel in
                sidebarRow("# " + channel, selected: channel == channels[1])
            }
            sectionTitle(isJapanese ? "ダイレクトメッセージ" : "Direct Messages").padding(.top, 12)
            ForEach(people, id: \.self) { sidebarRow($0, selected: false) }
            Spacer()
        }
        .padding(.top, 48)
        .padding(.horizontal, 12)
        .frame(width: 220, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.045))
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }

    private func sidebarRow(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: selected ? .semibold : .regular))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.primary.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }

    private func row(_ message: Message) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(message.color.gradient)
                .frame(width: 36, height: 36)
                .overlay(Text(message.name.prefix(1)).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(message.name).font(.system(size: 13, weight: .bold))
                    Text(message.time).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Text(message.text).font(.system(size: 14))
            }
        }
    }

    private var messageField: some View {
        let placeholder = isJapanese ? "# \(channels[1]) へのメッセージ" : "Message #\(channels[1])"
        return Text(placeholder)
            .font(.system(size: 14))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.18)))
            .padding(20)
    }
}
/// A plain-text notes window, mostly hidden behind the chat app.
private struct MockNotesView: View {
    let isJapanese: Bool

    private var text: String {
        isJapanese
            ? "10/23（金）定例\n\n■ 議題\n・進捗の確認\n・リリース日の決定\n・次の作業の分担\n\n■ メモ\n・資料は午前中に共有\n・審査メモを英語で用意する"
            : "Weekly sync — Fri, Oct 23\n\nAgenda\n- Progress check\n- Release date\n- Who does what next\n\nNotes\n- Share the slides in the morning\n- Prepare the review notes"
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .lineSpacing(4)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor))
    }
}
#endif
