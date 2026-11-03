import AppKit

// AppKit lifecycle (D4): a SwiftUI `App` would rebuild `NSApp.mainMenu` and discard the hidden Edit menu.
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()
