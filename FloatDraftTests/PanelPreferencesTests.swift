import Foundation
import Testing
@testable import FloatDraft

struct PanelPreferencesTests {
    private let suiteName = "FloatDraftTests.PanelPreferences.\(UUID().uuidString)"

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }

    @Test func freshInstallDefaults() {
        withDefaults { defaults in
            let preferences = PanelPreferences(defaults: defaults)
            #expect(preferences.positionMode == .mouseCursor)
            #expect(preferences.isPinned == false)
            #expect(preferences.staysOpenAcrossSpaces)
            #expect(preferences.savedOrigin == nil)
            #expect(preferences.panelSize == PanelPreferences.defaultSize)
            #expect(preferences.theme == .paper)
            #expect(preferences.showsHistorySidebar == false)
        }
    }

    @Test func valuesPersistAcrossInstances() {
        withDefaults { defaults in
            let preferences = PanelPreferences(defaults: defaults)
            preferences.positionMode = .rememberLastPosition
            preferences.isPinned = true
            preferences.staysOpenAcrossSpaces = false
            preferences.savedOrigin = CGPoint(x: -1500.5, y: 320)
            preferences.panelSize = CGSize(width: 500, height: 260)
            preferences.theme = .indigo
            preferences.showsHistorySidebar = true

            let reloaded = PanelPreferences(defaults: defaults)
            #expect(reloaded.positionMode == .rememberLastPosition)
            #expect(reloaded.isPinned == true)
            #expect(reloaded.staysOpenAcrossSpaces == false)
            #expect(reloaded.savedOrigin == CGPoint(x: -1500.5, y: 320))
            #expect(reloaded.panelSize == CGSize(width: 500, height: 260))
            #expect(reloaded.theme == .indigo)
            #expect(reloaded.showsHistorySidebar)
        }
    }

    @Test func unknownStoredModeFallsBackToMouseCursor() {
        withDefaults { defaults in
            defaults.set("bogus", forKey: "panel.positionMode")
            #expect(PanelPreferences(defaults: defaults).positionMode == .mouseCursor)
        }
    }
}
