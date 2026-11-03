import AppKit
import KeyboardShortcuts

/// Menu bar icon: left click toggles the panel, right click (or Control-click) opens the menu.
final class StatusItemController: NSObject, NSMenuItemValidation {
    private let statusItem: NSStatusItem
    private let panelController: PanelController
    private weak var appDelegate: AppDelegate?
    private lazy var menu = makeMenu()

    init(panelController: PanelController, appDelegate: AppDelegate) {
        self.panelController = panelController
        self.appDelegate = appDelegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "FloatDraft")
        image?.isTemplate = true
        button.image = image
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            panelController.toggle(source: .statusItem)
        }
    }

    private func showMenu() {
        // Attaching the menu only for this click keeps left click free for toggling.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let show = addItem(to: menu, "Show Draft", #selector(showDraft(_:)))
        show.setShortcut(for: .togglePanel)
        addItem(to: menu, "History…", #selector(showHistory(_:)))
        addItem(to: menu, "Re-copy Last", #selector(reCopyLast(_:)))
        menu.addItem(.separator())

        for mode in PanelPositionMode.allCases {
            let item = addItem(to: menu, title(for: mode), #selector(selectPositionMode(_:)))
            item.representedObject = mode.rawValue
        }
        menu.addItem(.separator())

        addItem(to: menu, "Settings…", #selector(showSettings(_:)))
        addItem(to: menu, "Welcome Guide…", #selector(showOnboarding(_:)))
        addItem(to: menu, "About FloatDraft", #selector(showAbout(_:)))
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit FloatDraft"),
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        return menu
    }

    @discardableResult
    private func addItem(to menu: NSMenu, _ title: String.LocalizationValue, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: title), action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func title(for mode: PanelPositionMode) -> String.LocalizationValue {
        switch mode {
        case .mouseCursor: "Open at Mouse Cursor"
        case .rememberLastPosition: "Open at Last Dragged Position"
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(selectPositionMode(_:)):
            let isCurrent = menuItem.representedObject as? String == panelController.preferences.positionMode.rawValue
            menuItem.state = isCurrent ? .on : .off
            return true
        case #selector(reCopyLast(_:)):
            return panelController.history.lastCopiedText != nil
        default:
            return true
        }
    }

    @objc private func showDraft(_ sender: Any?) {
        panelController.panel.isVisible ? panelController.focus() : panelController.show()
    }

    @objc private func showHistory(_ sender: Any?) {
        showDraft(sender)
        panelController.setHistorySidebarVisible(true)
    }

    @objc private func reCopyLast(_ sender: Any?) {
        panelController.reCopyLast()
    }

    @objc private func selectPositionMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = PanelPositionMode(rawValue: raw) else { return }
        panelController.preferences.positionMode = mode
    }

    @objc private func showSettings(_ sender: Any?) {
        appDelegate?.showSettings(sender)
    }

    @objc private func showOnboarding(_ sender: Any?) {
        appDelegate?.showOnboarding(sender)
    }

    @objc private func showAbout(_ sender: Any?) {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(sender)
    }
}
