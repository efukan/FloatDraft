import AppKit
import KeyboardShortcuts
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let onboardingCompletedKey = "onboarding.completed"

    private let loginItem = LoginItemController()
    private lazy var panelController = Self.makePanelController()
    private var preferences: PanelPreferences { panelController.preferences }
    private var statusItemController: StatusItemController?
    private var settingsWindow: HostedWindowController?
    private var onboardingWindow: HostedWindowController?

    /// Hosted unit tests launch the app too; keep first-run UI out of their way.
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        trackAppearanceMode()
        NSApp.mainMenu = MainMenu.make()
        panelController.openSettingsWindow = { [weak self] in self?.showSettings(nil) }
        statusItemController = StatusItemController(panelController: panelController, appDelegate: self)
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.panelController.toggle(source: .hotkey)
        }
        NSApp.servicesProvider = ServicesProvider(panelController: panelController)
        IntentTarget.panelController = panelController
        #if DEBUG
        if let scene = ScreenshotDemo.scene {
            ScreenshotDemo.stage(scene, in: panelController)
            return
        }
        // Smoke-test hook: `open FloatDraft.app --args -showPanelOnLaunch [-overlay history|quickSettings]`
        // shows the panel (and optionally an overlay) without the hotkey.
        if ProcessInfo.processInfo.arguments.contains("-showPanelOnLaunch") {
            panelController.show()
            switch UserDefaults.standard.string(forKey: "overlay") {
            case "history": panelController.setHistorySidebarVisible(true)
            case "quickSettings": panelController.setOverlay(.quickSettings)
            default: break
            }
            // `-clearHistoryPreview YES`: the sidebar asking to confirm Clear Unpinned.
            if UserDefaults.standard.bool(forKey: "clearHistoryPreview") {
                panelController.setHistorySidebarVisible(true)
                panelController.requestClearHistory()
            }
            // `-tooltipPreview YES`: the tooltip as it appears under the header's rightmost icon (History).
            if UserDefaults.standard.bool(forKey: "tooltipPreview") {
                let panel = panelController.panel.frame
                let icon = NSRect(x: panel.maxX - 8 - 28, y: panel.maxY - 29, width: 28, height: 24)
                HoverTooltip.shared.show(Text("History (⌘Y)"), below: icon, within: panel)
            }
            return
        }
        if ProcessInfo.processInfo.arguments.contains("-showSettingsOnLaunch") {
            showSettings(nil)
            return
        }
        #endif
        if !isRunningTests && !UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey) {
            showOnboarding(nil)
        }
    }

    private static func makePanelController() -> PanelController {
        #if DEBUG
        if ScreenshotDemo.scene != nil {
            return ScreenshotDemo.makePanelController()
        }
        #endif
        return PanelController(
            preferences: PanelPreferences(),
            editor: EditorController(draftStore: DraftStore()),
            history: HistoryStore()
        )
    }

    /// Applies Settings › Appearance (system / light / dark) to every window, now and whenever it changes.
    private func trackAppearanceMode() {
        withObservationTracking {
            NSApp.appearance = preferences.appearanceMode.appearance
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackAppearanceMode() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController.editor.saveDraft()
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            settingsWindow = HostedWindowController(
                title: String(localized: "FloatDraft Settings"),
                rootView: SettingsView(preferences: preferences, loginItem: loginItem),
                onClose: { [weak self] in self?.panelController.appWindowDidClose() }
            )
        }
        panelController.suspendForAppWindow()
        settingsWindow?.show()
    }

    @objc func showOnboarding(_ sender: Any?) {
        if onboardingWindow == nil {
            onboardingWindow = HostedWindowController(
                title: String(localized: "Welcome to FloatDraft"),
                rootView: OnboardingView(
                    tryIt: { [weak self] in
                        self?.onboardingWindow?.close()
                        self?.panelController.show()
                    },
                    openSettings: { [weak self] in self?.showSettings(nil) }
                ),
                onClose: { UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey) }
            )
        }
        onboardingWindow?.show()
    }
}
