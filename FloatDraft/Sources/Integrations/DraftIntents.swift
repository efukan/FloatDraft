import AppIntents

/// The running app's panel, which the App Intents act on. Set at launch by the app delegate.
enum IntentTarget {
    static weak var panelController: PanelController?

    static func current() throws(ExternalTextError) -> PanelController {
        guard let panelController else { throw .notReady }
        return panelController
    }
}

/// Opens the draft panel next to the pointer, like the global shortcut.
struct OpenDraftPanelIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Draft Panel"
    static let description: IntentDescription? = IntentDescription(
        "Opens the FloatDraft panel next to the pointer, ready for typing.")

    @MainActor func perform() async throws -> some IntentResult {
        try IntentTarget.current().showEditor()
        return .result()
    }
}

/// Adds text to the draft, as the Services menu does: a blank draft is replaced, otherwise the text is
/// appended on a new line. One undo step in the editor.
struct AddTextToDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Text to Draft"
    static let description: IntentDescription? = IntentDescription(
        "Adds text to the FloatDraft draft. An empty draft is replaced; otherwise the text is added on a new line at the end. You can undo it with Command-Z in the panel.")

    @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    @Parameter(title: "Open Panel", default: true)
    var openPanel: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$text) to the draft") {
            \.$openPanel
        }
    }

    init() {}

    init(text: String, openPanel: Bool = true) {
        self.text = text
        self.openPanel = openPanel
    }

    @MainActor func perform() async throws -> some IntentResult {
        try IntentTarget.current().addExternalText(text, showingPanel: openPanel)
        return .result()
    }
}

/// Returns the text of the last Copy & Clear from FloatDraft's own history (the same text Re-copy uses).
/// It never reads the clipboard (E18). Empty text when nothing has been copied yet.
struct GetLastCopiedTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Last Copied Text"
    static let description: IntentDescription? = IntentDescription(
        "Returns the text you last copied with Copy & Clear in FloatDraft, or empty text if there is none.")

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: try IntentTarget.current().history.lastCopiedText ?? "")
    }
}

/// Suggested shortcuts, available in Shortcuts and Spotlight without any setup.
struct FloatDraftShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenDraftPanelIntent(),
            phrases: ["Open a draft in \(.applicationName)", "New \(.applicationName) draft"],
            shortTitle: "Open Draft Panel",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: AddTextToDraftIntent(),
            phrases: ["Add text to \(.applicationName)"],
            shortTitle: "Add Text to Draft",
            systemImageName: "text.append"
        )
        AppShortcut(
            intent: GetLastCopiedTextIntent(),
            phrases: ["Get the last copied text from \(.applicationName)"],
            shortTitle: "Get Last Copied Text",
            systemImageName: "arrow.uturn.backward"
        )
    }
}
