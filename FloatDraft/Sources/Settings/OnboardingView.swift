import KeyboardShortcuts
import SwiftUI

/// First-launch welcome (D8). A menu-bar-only app is otherwise invisible after launch, which also
/// leaves App Review without an obvious starting point (Guideline 2.1).
struct OnboardingView: View {
    let tryIt: () -> Void
    let openSettings: () -> Void

    private var shortcut: String {
        KeyboardShortcuts.getShortcut(for: .togglePanel)?.description ?? String(localized: "(not set)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to FloatDraft")
                        .font(.title2.bold())
                    Text("Write first. Send when you mean it.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Feature(systemImage: "keyboard",
                        text: "Press \(shortcut) in any app to open a draft panel next to your pointer.")
                Feature(systemImage: "return",
                        text: "Return always adds a new line, and confirming Japanese input never triggers anything — so nothing gets sent by accident.")
                Feature(systemImage: "doc.on.clipboard",
                        text: "Press ⌘Return to copy and clear the draft. You're taken back to your app; press ⌘V to paste.")
                Feature(systemImage: "clock.arrow.circlepath",
                        text: "Recent drafts stay in History, on this Mac only. Quote, code-block and tidy tools are in the panel's header.")
                Feature(systemImage: "menubar.arrow.up.rectangle",
                        text: "FloatDraft lives in the menu bar. Click its icon to open the panel; right-click for Settings.")
            }

            HStack {
                Button("Change Shortcut…", action: openSettings)
                Spacer()
                Button("Try It Now", action: tryIt)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Feature: View {
    let systemImage: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
