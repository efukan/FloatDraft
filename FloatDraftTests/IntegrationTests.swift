import AppIntents
import AppKit
import Testing
@testable import FloatDraft

/// The Services menu ("Edit in FloatDraft") and the App Intents for Shortcuts. Both add text from outside
/// the editor, so both must be undoable and must never touch a draft that is mid-composition (E9).
@Suite(.serialized)
struct IntegrationTests {
    private let environment = TestEnvironment()

    /// A service pasteboard as the system would hand it over: private, never the general clipboard.
    private func servicePasteboard(_ text: String) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("FloatDraftTests.service.\(UUID().uuidString)"))
        Clipboard.write(text, to: pasteboard)
        return pasteboard
    }

    /// Runs `body` with the App Intents pointed at `controller`, restoring the app's own panel afterwards.
    private func withIntentTarget(_ controller: PanelController?, _ body: () async throws -> Void) async rethrows {
        let previous = IntentTarget.panelController
        IntentTarget.panelController = controller
        defer { IntentTarget.panelController = previous }
        try await body()
    }

    // MARK: Services menu

    @Test func serviceFillsEmptyDraftAndOpensPanel() {
        let controller = environment.makePanelController()
        defer { controller.hide(restoringFocus: false) }
        let pasteboard = servicePasteboard("selected text")
        defer { pasteboard.releaseGlobally() }

        #expect(ServicesProvider(panelController: controller).receive(from: pasteboard) == nil)
        #expect(controller.editor.textView.string == "selected text")
        #expect(controller.panel.isVisible)
        #expect(controller.panel.firstResponder === controller.editor.textView)
    }

    @Test func serviceAppendsToExistingDraftAsOneUndoStep() {
        let controller = environment.makePanelController()
        defer { controller.hide(restoringFocus: false) }
        controller.editor.textView.string = "draft"
        let pasteboard = servicePasteboard("quote")
        defer { pasteboard.releaseGlobally() }

        #expect(ServicesProvider(panelController: controller).receive(from: pasteboard) == nil)
        #expect(controller.editor.textView.string == "draft\nquote")
        #expect(controller.editor.textView.selectedRange() == NSRange(location: 11, length: 0))
        controller.editor.textView.undoManager?.undo()
        #expect(controller.editor.textView.string == "draft")
    }

    @Test func serviceLeavesCompositionUntouchedAndReportsWhy() {
        let controller = environment.makePanelController()
        defer { controller.hide(restoringFocus: false) }
        controller.focus()
        controller.editor.textView.beginComposition("にほんご")
        let pasteboard = servicePasteboard("selected text")
        defer { pasteboard.releaseGlobally() }

        let message = ServicesProvider(panelController: controller).receive(from: pasteboard)
        #expect(message == String(localized: ExternalTextError.composing.localizedStringResource))
        #expect(controller.editor.textView.hasMarkedText())
        #expect(controller.editor.textView.string == "にほんご")
        #expect(controller.panel.isVisible)
    }

    @Test func serviceWithoutTextChangesNothing() {
        let controller = environment.makePanelController()
        defer { controller.hide(restoringFocus: false) }
        controller.editor.textView.string = "draft"
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("FloatDraftTests.service.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()

        #expect(ServicesProvider(panelController: controller).receive(from: pasteboard) != nil)
        #expect(controller.editor.textView.string == "draft")
    }

    @Test func serviceIsDeclaredForPlainTextAndMatchesTheHandler() throws {
        let services = try #require(Bundle.main.infoDictionary?["NSServices"] as? [[String: Any]])
        let service = try #require(services.first)
        #expect(service["NSSendTypes"] as? [String] == ["public.utf8-plain-text"])
        #expect(service["NSReturnTypes"] == nil)
        let message = try #require(service["NSMessage"] as? String)
        #expect(ServicesProvider.instancesRespond(to: Selector("\(message):userData:error:")))
        #expect((service["NSMenuItem"] as? [String: String])?["default"] == "Edit in FloatDraft")
    }

    @Test func serviceMenuTitleIsTranslated() throws {
        let path = try #require(Bundle.main.path(forResource: "ja", ofType: "lproj"))
        let japanese = try #require(Bundle(path: path))
        #expect(japanese.localizedString(forKey: "Edit in FloatDraft", value: nil, table: "ServicesMenu")
            == "FloatDraft で編集")
    }

    // MARK: App Intents

    @Test func openPanelIntentShowsTheEditor() async throws {
        let controller = environment.makePanelController()
        defer { controller.hide(restoringFocus: false) }
        controller.setOverlay(.quickSettings)
        try await withIntentTarget(controller) {
            _ = try await OpenDraftPanelIntent().perform()
        }
        #expect(controller.panel.isVisible)
        #expect(controller.ui.overlay == nil)
        #expect(controller.panel.firstResponder === controller.editor.textView)
    }

    @Test func addTextIntentAppendsAndCanStayHidden() async throws {
        let controller = environment.makePanelController()
        defer { controller.hide(restoringFocus: false) }
        controller.editor.textView.string = "line one\n"
        try await withIntentTarget(controller) {
            _ = try await AddTextToDraftIntent(text: "line two", openPanel: false).perform()
        }
        #expect(controller.editor.textView.string == "line one\nline two")
        #expect(controller.panel.isVisible == false)
        controller.editor.textView.undoManager?.undo()
        #expect(controller.editor.textView.string == "line one\n")
    }

    @Test func addTextIntentFailsWhileComposing() async {
        let controller = environment.makePanelController()
        defer { controller.hide(restoringFocus: false) }
        controller.focus()
        controller.editor.textView.beginComposition("へんかん")
        await withIntentTarget(controller) {
            await #expect(throws: ExternalTextError.composing) {
                _ = try await AddTextToDraftIntent(text: "x").perform()
            }
        }
        #expect(controller.editor.textView.string == "へんかん")
    }

    @Test func addTextIntentRejectsBlankText() async {
        let controller = environment.makePanelController()
        controller.editor.textView.string = "draft"
        await withIntentTarget(controller) {
            await #expect(throws: ExternalTextError.nothingToAdd) {
                _ = try await AddTextToDraftIntent(text: " \n", openPanel: false).perform()
            }
        }
        #expect(controller.editor.textView.string == "draft")
    }

    @Test func lastCopiedTextIntentReturnsHistoryNotClipboard() async throws {
        let controller = environment.makePanelController()
        Clipboard.write("unrelated clipboard", to: environment.pasteboard)
        var results: [String?] = []
        try await withIntentTarget(controller) {
            results.append(try await GetLastCopiedTextIntent().perform().value)
            controller.history.add("sent draft")
            results.append(try await GetLastCopiedTextIntent().perform().value)
        }
        #expect(results == ["", "sent draft"])
    }

    @Test func intentsReportNotReadyWithoutAPanel() async {
        await withIntentTarget(nil) {
            await #expect(throws: ExternalTextError.notReady) {
                _ = try await OpenDraftPanelIntent().perform()
            }
        }
    }

    @Test func appShortcutsCoverEveryIntent() {
        #expect(FloatDraftShortcuts.appShortcuts.count == 3)
    }
}
