import AppKit
import Testing
@testable import FloatDraft

/// Regressions found on the Graphite theme in light mode.
@Suite(.serialized)
struct ThemeRegressionTests {
    private let environment = TestEnvironment()

    private func graphiteController() async throws -> PanelController {
        let controller = environment.makePanelController()
        controller.editor.textView.string = ""
        controller.focus()
        controller.preferences.theme = .graphite
        try await Task.sleep(for: .milliseconds(50))
        return controller
    }

    private func expectEditorAttributes(_ textView: DraftTextView, sourceLocation: SourceLocation = #_sourceLocation) {
        let attributes = textView.textStorage!.attributes(at: 0, effectiveRange: nil)
        #expect(attributes[.foregroundColor] as? NSColor == PanelTheme.graphite.palette.text,
                "not default black, which is invisible on Graphite", sourceLocation: sourceLocation)
        #expect(attributes[.font] as? NSFont == textView.font, sourceLocation: sourceLocation)
    }

    @Test func restoringIntoAnEmptyEditorKeepsThemeTextColor() async throws {
        let controller = try await graphiteController()
        defer { controller.hide(restoringFocus: false) }
        controller.history.add("from history")
        controller.restore(try #require(controller.history.items.first))
        expectEditorAttributes(controller.editor.textView)
    }

    @Test func insertingIntoAnEmptyEditorKeepsThemeTextColor() async throws {
        let controller = try await graphiteController()
        defer { controller.hide(restoringFocus: false) }
        controller.history.add("snippet")
        controller.insert(try #require(controller.history.items.first))
        expectEditorAttributes(controller.editor.textView)
    }

    @Test func externalTextIntoAnEmptyEditorKeepsThemeTextColor() async throws {
        let controller = try await graphiteController()
        defer { controller.hide(restoringFocus: false) }
        try controller.addExternalText("from Services", showingPanel: false)
        expectEditorAttributes(controller.editor.textView)
    }

    @Test func swatchColorsResolveForTheRequestedAppearance() throws {
        let header = PanelTheme.paper.palette.header
        let light = header.resolved(for: try #require(NSAppearance(named: .aqua)))
        let dark = header.resolved(for: try #require(NSAppearance(named: .darkAqua)))
        #expect(abs(light.redComponent - 0xF1 / 255.0) < 0.01, "Paper's light header, even inside a dark panel")
        #expect(abs(dark.redComponent - 0x2B / 255.0) < 0.01)
    }
}
