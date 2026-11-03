import AppKit

/// Hidden main menu (D4 first tier). An agent app never shows a menu bar, but key equivalents such as
/// ⌘C / ⌘V / ⌘Z are dispatched through `NSApp.mainMenu`, so without it the editor only beeps.
///
/// ⌘Return and Esc are deliberately absent (D2): menu key equivalents fire before the input method,
/// so they would bypass the IME guard. Items that change text are disabled while composing (E9).
enum MainMenu {
    static func make() -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(submenuItem(appMenu()))
        mainMenu.addItem(submenuItem(editMenu()))
        mainMenu.addItem(submenuItem(formatMenu()))
        mainMenu.addItem(submenuItem(viewMenu()))
        return mainMenu
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "FloatDraft")
        menu.addItem(withTitle: String(localized: "About FloatDraft"),
                     action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                     keyEquivalent: "")
        // Handled by AppDelegate through the responder chain.
        menu.addItem(item("Settings…", #selector(AppDelegate.showSettings(_:)), ","))
        // Deliberately no ⌘Q here: pressing it while the panel has focus must not quit FloatDraft.
        // Quit lives in the status item menu.
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Edit"))
        menu.addItem(item("Undo", Selector(("undo:")), "z"))
        menu.addItem(item("Redo", Selector(("redo:")), "Z"))
        menu.addItem(.separator())
        menu.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        menu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        menu.addItem(item("Paste and Match Style", #selector(NSTextView.pasteAsPlainText(_:)), "V", [.command, .option]))
        menu.addItem(item("Delete", #selector(NSText.delete(_:)), ""))
        menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        return menu
    }

    private static func formatMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Format"))
        // ">" is Shift-. on both US and JIS layouts, so this is ⌘⇧. ; "K" is ⌘⇧K.
        menu.addItem(item("Quote", #selector(DraftTextView.toggleQuote(_:)), ">"))
        menu.addItem(item("Code Block", #selector(DraftTextView.wrapInCodeBlock(_:)), "K"))
        menu.addItem(item("Tidy Whitespace", #selector(DraftTextView.tidyWhitespace(_:)), ""))
        menu.addItem(.separator())
        // ⌘1–⌘9 insert the pinned history items in sidebar order (handled by PanelController).
        for number in 1...9 {
            let insert = item("Insert Pinned Item", #selector(PanelController.insertPinnedItem(_:)), "\(number)")
            insert.tag = number
            menu.addItem(insert)
        }
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "View"))
        // Handled by PanelController (the panel's delegate) through the responder chain.
        menu.addItem(item("History", #selector(PanelController.toggleHistory(_:)), "y"))
        menu.addItem(.separator())
        // "+" is ⌘+ with Shift on US layouts; "=" also accepts the unshifted key, as many apps do.
        menu.addItem(item("Bigger", #selector(PanelController.increaseEditorFontSize(_:)), "+"))
        menu.addItem(item("Bigger", #selector(PanelController.increaseEditorFontSize(_:)), "="))
        menu.addItem(item("Smaller", #selector(PanelController.decreaseEditorFontSize(_:)), "-"))
        menu.addItem(item("Actual Size", #selector(PanelController.resetEditorFontSize(_:)), "0"))
        return menu
    }

    /// An uppercase key equivalent implies Shift (e.g. "Z" is ⇧⌘Z).
    private static func item(
        _ title: String.LocalizationValue,
        _ action: Selector,
        _ key: String,
        _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: title), action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private static func submenuItem(_ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }
}
