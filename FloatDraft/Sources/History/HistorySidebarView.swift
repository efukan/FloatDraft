import SwiftUI

/// History beside the editor, inside the panel (never a separate window, which would close the panel).
/// The editor stays visible, so past drafts can be compared with the current one before restoring.
struct HistorySidebarView: View {
    let history: HistoryStore
    @Bindable var ui: PanelUIState
    let preferences: PanelPreferences
    let actions: PanelActions

    private var palette: PanelPalette { preferences.theme.palette }
    private var pinned: [HistoryItem] { history.pinnedItems.filter { history.matches($0, query: ui.historyQuery) } }
    private var recent: [HistoryItem] { history.recentItems.filter { history.matches($0, query: ui.historyQuery) } }
    private var visible: [HistoryItem] { history.visibleItems(query: ui.historyQuery) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                HistorySearchField(
                    text: $ui.historyQuery,
                    focusRequest: ui.historySearchFocusRequest,
                    onSubmit: { HistoryNavigation.target(ui.historySelection, in: visible).map(actions.restore) },
                    onInsert: { HistoryNavigation.target(ui.historySelection, in: visible).map(actions.insert) },
                    onMove: { ui.historySelection = HistoryNavigation.move(ui.historySelection, by: $0, in: visible) },
                    onCancel: actions.focusEditor
                )
                Button(action: actions.toggleHistory) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: palette.icon))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .hoverTooltip("Hide history (⌘Y)")
                .accessibilityLabel(Text("Hide history (⌘Y)"))
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if pinned.isEmpty && recent.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 22))
                    Text(history.items.isEmpty ? "No History Yet" : "No Matches")
                        .font(.system(size: 12, weight: .semibold))
                    Text(history.items.isEmpty
                         ? "Drafts you send with Copy & Clear appear here."
                         : "Try a different search.")
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color(nsColor: palette.secondaryText))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            if !pinned.isEmpty {
                                SectionHeader(title: "Pinned", palette: palette)
                                ForEach(Array(pinned.enumerated()), id: \.element.id) { index, item in
                                    row(item, shortcutNumber: index < 9 ? index + 1 : nil)
                                }
                            }
                            if !recent.isEmpty {
                                SectionHeader(title: "Recent", palette: palette)
                                ForEach(recent) { row($0, shortcutNumber: nil) }
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                    }
                    .onChange(of: ui.historySelection) { _, selection in
                        if let selection { proxy.scrollTo(selection) }
                    }
                }
            }

            if ui.isConfirmingClearHistory {
                clearConfirmation
            } else {
                footer
            }
        }
        // A new search starts from the top of the results.
        .onChange(of: ui.historyQuery) { ui.historySelection = nil }
    }

    private var footer: some View {
        HStack {
            Text("\(history.recentItems.count) of \(HistoryStore.unpinnedLimit) recent")
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: palette.secondaryText))
                .lineLimit(1)
                .hoverTooltip("History is stored on this Mac only.")
            Spacer(minLength: 4)
            Button("Clear Unpinned", action: actions.requestClearHistory)
                .buttonStyle(PanelTextButtonStyle(palette: palette))
                .focusable(false)
                .disabled(history.recentItems.isEmpty)
                .hoverTooltip("Delete every history item except pinned ones")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    /// Asked in place: a sheet or alert would take key focus from the panel and close it.
    private var clearConfirmation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Delete \(history.recentItems.count) unpinned items? This can't be undone.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: palette.text))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: actions.cancelClearHistory)
                    .controlSize(.small)
                    .focusable(false)
                Button("Delete", role: .destructive, action: actions.confirmClearHistory)
                    .controlSize(.small)
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
                    .focusable(false)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: palette.hover))
    }

    private func row(_ item: HistoryItem, shortcutNumber: Int?) -> some View {
        HistoryRow(item: item, history: history, palette: palette, actions: actions,
                   isSelected: item.id == ui.historySelection, shortcutNumber: shortcutNumber)
            .id(item.id)
    }
}

private struct SectionHeader: View {
    let title: LocalizedStringKey
    let palette: PanelPalette

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color(nsColor: palette.secondaryText))
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    let history: HistoryStore
    let palette: PanelPalette
    let actions: PanelActions
    let isSelected: Bool
    /// 1–9 for the first nine pinned items (⌘1–⌘9 inserts them).
    let shortcutNumber: Int?
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            Button {
                // ⌥-click inserts at the caret (snippet use); a plain click replaces the draft.
                if NSEvent.modifierFlags.contains(.option) {
                    actions.insert(item)
                } else {
                    actions.restore(item)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: palette.text))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        Text(item.copiedAt, format: .relative(presentation: .named))
                        if let shortcutNumber {
                            Text(verbatim: "⌘\(shortcutNumber)")
                                .monospacedDigit()
                                .padding(.horizontal, 4)
                                .background(Color(nsColor: palette.hover), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: palette.secondaryText))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .hoverTooltip("Click to replace the draft, ⌥-click to insert at the cursor (⌘Z undoes either)")

            // Pin and delete appear on hover (a pinned item always shows its pin) to keep the list calm.
            if isHovered || item.isPinned {
                RowIconButton(systemImage: item.isPinned ? "pin.fill" : "pin",
                              help: item.isPinned ? "Unpin" : "Pin", palette: palette) {
                    history.togglePin(item.id)
                }
            }
            if isHovered {
                RowIconButton(systemImage: "trash", help: "Delete", palette: palette) {
                    history.delete(item.id)
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 7))
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isSelected { return Color(nsColor: palette.selection) }
        return isHovered ? Color(nsColor: palette.hover) : .clear
    }
}

private struct RowIconButton: View {
    let systemImage: String
    let help: LocalizedStringKey
    let palette: PanelPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: palette.icon))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .hoverTooltip(help)
        .accessibilityLabel(Text(help))
    }
}
