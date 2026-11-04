// Makes the App Store screenshots (2880×1800, 16:10) in Japanese and English.
//
//   scripts/verify.sh --quick                # builds the Debug app this script launches
//   swift scripts/make-screenshots.swift     # → build/screenshots/{ja,en}/N-scene.png
//
// Each scene is staged by the Debug-only `-screenshotScene` hook (ScreenshotDemo.swift), which uses
// throwaway stores, so the real draft, history, settings and clipboard are left alone. Its windows (a made-up
// chat app, the panel, the copy confirmation) are captured with `screencapture -l` and laid out at their real
// size on a desktop as on a 1440×900 Retina screen: a drawn blue background and menu bar.
// The demo activates itself to keep the panel open: leave the keyboard and mouse alone while this runs.
import AppKit
import CoreImage

let app = "build/DerivedData/Build/Products/Debug/FloatDraft.app/Contents/MacOS/FloatDraft"
let environment = ProcessInfo.processInfo.environment
let outputRoot = URL(fileURLWithPath: environment["OUTPUT"] ?? "build/screenshots")
/// For trying out changes: SCENES=open,compose, LANGS=ja.
let sceneFilter = environment["SCENES"].map { Set($0.split(separator: ",").map(String.init)) }
let languages = environment["LANGS"].map { $0.split(separator: ",").map(String.init) } ?? ["ja", "en"]
let canvas = CGSize(width: 2880, height: 1800)

struct Scene {
    var name: String
    /// The windows behind the panel are dark, except behind the dark panel of the themes scene.
    var lightWindows = false
    var caption: [String: (title: String, subtitle: String)]
}

/// Other companies' product names never appear here (Guideline 2.3 / 5.2.1).
/// The order tells the story: open it anywhere, write without fear of sending, paste, then the extras.
let scenes = [
    Scene(name: "open", caption: [
        "ja": ("ショートカットひとつで、すぐ下書き", "どのアプリを使っていても、マウスのそばに下書きパネルが開きます"),
        "en": ("Start a draft with one shortcut", "From any app, a small draft panel opens right by your pointer"),
    ]),
    Scene(name: "compose", caption: [
        "ja": ("Return は改行。送信されません", "変換を確定しても、何度改行しても、書きかけのまま送られることはありません"),
        "en": ("Return just adds a new line", "Confirm input-method text and break lines freely — nothing is sent half-written"),
    ]),
    Scene(name: "copied", caption: [
        "ja": ("⌘Return でコピー、⌘V で貼るだけ", "書き終えたらコピーして、元のアプリに戻ります"),
        "en": ("⌘Return to copy, ⌘V to paste", "When you're done, FloatDraft copies the text and takes you back"),
    ]),
    Scene(name: "tidy", caption: [
        "ja": ("送る前に、整える", "引用・コードブロック・空白の整理。⌘Z でいつでも元に戻せます"),
        "en": ("Tidy up before you send", "Quotes, code blocks and whitespace cleanup — undo any of it with ⌘Z"),
    ]),
    Scene(name: "history", caption: [
        "ja": ("送った下書きは、履歴から呼び戻せる", "検索・ピン留め・ワンクリックで復元"),
        "en": ("Every sent draft, in History", "Search, pin, and bring one back with a click"),
    ]),
    Scene(name: "themes", lightWindows: true, caption: [
        "ja": ("好みの見た目で", "5 つのテーマとダークモード。データはこの Mac の中だけに保存されます"),
        "en": ("Make it yours", "Five themes and Dark Mode. Everything stays on your Mac"),
    ]),
]

// MARK: - Capture

struct Shot {
    var chat: NSImage
    var notes: NSImage
    var panel: NSImage?
    var toast: NSImage?
}

struct WindowInfo {
    var id: CGWindowID
    var layer: Int
    var size: CGSize
}

func run(_ path: String, _ arguments: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    try! process.run()
    process.waitUntilExit()
}

/// On-screen windows of `pid`, largest first, leaving out the menu bar icon and the screen-sized plain
/// window the demo puts behind everything.
func windows(of pid: pid_t) -> [WindowInfo] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return list.compactMap { info -> WindowInfo? in
        guard info[kCGWindowOwnerPID as String] as? pid_t == pid,
              let id = info[kCGWindowNumber as String] as? CGWindowID,
              let layer = info[kCGWindowLayer as String] as? Int,
              let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
              let width = bounds["Width"], let height = bounds["Height"],
              width >= 120, height >= 30, width < 1200 else { return nil }
        return WindowInfo(id: id, layer: layer, size: CGSize(width: width, height: height))
    }
    .sorted { $0.size.width * $0.size.height > $1.size.width * $1.size.height }
}

func capture(_ window: CGWindowID) -> NSImage {
    let file = FileManager.default.temporaryDirectory.appending(path: "floatdraft-\(window).png")
    // -o: no system shadow; the composite draws its own.
    run("/usr/sbin/screencapture", ["-l\(window)", "-o", "-x", file.path])
    defer { try? FileManager.default.removeItem(at: file) }
    return NSImage(data: try! Data(contentsOf: file))!
}

/// Launches the demo for `scene` and captures the two app windows (layer 0; the chat one is larger)
/// and the floating panel or toast.
func captureScene(_ scene: Scene, language: String) -> Shot {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: app)
    process.arguments = ["-screenshotScene", scene.name, "-AppleLanguages", "(\(language))",
                         "-AppleLocale", language == "ja" ? "ja_JP" : "en_US"]
    try! process.run()
    defer { process.terminate(); process.waitUntilExit() }

    var found: [WindowInfo] = []
    for _ in 0..<50 {
        Thread.sleep(forTimeInterval: 0.2)
        found = windows(of: process.processIdentifier)
        if found.filter({ $0.layer == 0 }).count >= 2 && found.contains(where: { $0.layer > 0 }) { break }
    }
    let appWindows = found.filter { $0.layer == 0 }
    guard appWindows.count >= 2,
          let floating = found.first(where: { $0.layer > 0 }) else { fatalError("\(scene.name): windows did not appear") }
    Thread.sleep(forTimeInterval: 1.0) // Let SwiftUI and the sidebar settle.
    let isToast = floating.size.height < 100
    return Shot(chat: capture(appWindows[0].id), notes: capture(appWindows[1].id),
                panel: isToast ? nil : capture(floating.id),
                toast: isToast ? capture(floating.id) : nil)
}

// MARK: - Drawing

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func pixelSize(_ image: NSImage) -> CGSize {
    let rep = image.representations.first!
    return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
}

/// A rect given from the top-left, as the layout below thinks of it, in AppKit's bottom-left coordinates.
func rect(x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(x: x, y: canvas.height - top - height, width: width, height: height)
}

/// The desktop: a clear blue, the opposite of the app's warm colors, with no pattern behind the caption.
/// Soft light in the lower corners keeps it from looking like a flat slide.
func drawDesktop() {
    NSGradient(starting: color(0x2F6FDB), ending: color(0x1A3F9C))!.draw(in: NSRect(origin: .zero, size: canvas), angle: -60)
    for (center, hex, alpha, radius) in [(NSPoint(x: 2500, y: 200), UInt32(0x4FC3F7), CGFloat(0.4), CGFloat(1300)),
                                         (NSPoint(x: 200, y: 100), UInt32(0x5B3FD6), CGFloat(0.55), CGFloat(1200))] {
        NSGradient(colors: [color(hex, alpha: alpha), color(hex, alpha: 0)])!
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
    }
}

/// Draws an SF Symbol tinted `tint`, its left edge at `x` and centered on `midY`; returns its width.
@discardableResult
func drawSymbol(_ name: String, size: CGFloat, x: CGFloat, midY: CGFloat, tint: NSColor) -> CGFloat {
    let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: size, weight: .medium))!
    let tinted = NSImage(size: symbol.size, flipped: false) { bounds in
        symbol.draw(in: bounds)
        tint.set()
        bounds.fill(using: .sourceAtop)
        return true
    }
    tinted.draw(in: NSRect(x: x, y: midY - symbol.size.height / 2, width: symbol.size.width, height: symbol.size.height))
    return symbol.size.width
}

/// The menu bar of a 1440×900 pt screen at 2×: the chat app's menus on the left, FloatDraft's icon among
/// the status items on the right.
func drawMenuBar(language: String, panelIsOpen: Bool) {
    let height: CGFloat = 48
    let bar = rect(x: 0, top: 0, width: canvas.width, height: height)
    NSColor.black.withAlphaComponent(0.18).setFill()
    bar.fill()
    let ink = NSColor.white
    let midY = bar.midY
    @discardableResult
    func text(_ string: String, x: CGFloat, bold: Bool = false) -> CGFloat {
        let attributed = NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: bold ? .bold : .regular), .foregroundColor: ink,
        ])
        let size = attributed.size()
        attributed.draw(at: NSPoint(x: x, y: midY - size.height / 2))
        return size.width
    }

    var x: CGFloat = 40
    x += drawSymbol("apple.logo", size: 28, x: x, midY: midY + 1, tint: ink) + 44
    let menus = language == "ja"
        ? ["チャット", "ファイル", "編集", "表示", "ウインドウ", "ヘルプ"]
        : ["Chat", "File", "Edit", "View", "Window", "Help"]
    for (index, menu) in menus.enumerated() {
        x += text(menu, x: x, bold: index == 0) + 40
    }

    // A weekday morning: the notes window plans Friday's meeting, "tomorrow" in the chat.
    let clock = language == "ja" ? "10月22日(木)  10:24" : "Thu Oct 22  10:24 AM"
    let clockWidth = NSAttributedString(string: clock, attributes: [.font: NSFont.systemFont(ofSize: 26)]).size().width
    x = canvas.width - 36 - clockWidth
    text(clock, x: x)
    for symbol in ["switch.2", "wifi", "battery.100percent", "square.and.pencil"] {
        let width = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: 26, weight: .medium))!.size.width
        x -= width + 40
        if symbol == "square.and.pencil" && panelIsOpen {
            // FloatDraft's icon, highlighted as when its panel is open.
            NSColor.white.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: NSRect(x: x - 14, y: midY - 20, width: width + 28, height: 40),
                         xRadius: 8, yRadius: 8).fill()
        }
        drawSymbol(symbol, size: 26, x: x, midY: midY, tint: ink)
    }
}

func drawCaption(_ scene: Scene, language: String) {
    let (title, subtitle) = scene.caption[language]!
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    NSAttributedString(string: title, attributes: [
        .font: NSFont.systemFont(ofSize: 112, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: centered,
    ]).draw(in: rect(x: 120, top: 112, width: canvas.width - 240, height: 160))
    NSAttributedString(string: subtitle, attributes: [
        .font: NSFont.systemFont(ofSize: 50, weight: .regular),
        .foregroundColor: NSColor.white.withAlphaComponent(0.92),
        .paragraphStyle: centered,
    ]).draw(in: rect(x: 120, top: 280, width: canvas.width - 240, height: 80))
}

func drawWindow(_ image: NSImage, in frame: NSRect, blur: CGFloat, offset: CGFloat, opacity: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(opacity)
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: -offset)
    shadow.set()
    image.draw(in: frame)
    NSGraphicsContext.restoreGraphicsState()
}

/// A window behind the panel, pushed back: dimmed and less saturated, so the panel reads as the subject while
/// the desktop still looks real. The window keeps its exact shape (rounded corners).
func receded(_ image: NSImage, light: Bool) -> NSImage {
    let source = CIImage(data: image.tiffRepresentation!)!
    let toned = source
        .applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.7,
            // On dark windows the light text is what stands out, so it is toned down further.
            kCIInputBrightnessKey: light ? -0.06 : -0.13,
            kCIInputContrastKey: light ? 0.9 : 0.7,
        ])
        .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: source])
    return NSImage(cgImage: CIContext().createCGImage(toned, from: source.extent)!, size: pixelSize(image))
}

/// The colored traffic lights of the active window, over the captured ones: the panel leaves the app behind it active,
/// but whether the demo gets to look that way depends on which app was frontmost when the script ran.
func drawTrafficLights(on window: NSRect) {
    for (offset, hex) in [(CGFloat(32), UInt32(0xEC6A5E)), (78, 0xF4BF4F), (124, 0x61C554)] {
        color(hex).setFill()
        NSBezierPath(ovalIn: NSRect(x: window.minX + offset - 15, y: window.maxY - 32 - 15, width: 30, height: 30)).fill()
    }
}

/// ⌃ ⇧ Space as keyboard keys, from `left`, centered on `midTop` (top-left coordinates).
func drawShortcutKeys(left: CGFloat, midTop: CGFloat) {
    let keys: [(String, CGFloat)] = [("⌃", 110), ("⇧", 110), ("Space", 260)]
    let height: CGFloat = 110
    let gap: CGFloat = 20
    var x = left
    for (label, width) in keys {
        let frame = rect(x: x, top: midTop - height / 2, width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.set()
        // The key's side, then its face: a little depth, like a real keycap.
        color(0xD9D6D3).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 22, yRadius: 22).fill()
        NSGraphicsContext.restoreGraphicsState()
        let face = frame.insetBy(dx: 4, dy: 4).offsetBy(dx: 0, dy: 5)
        NSGradient(starting: .white, ending: color(0xF2F0EE))!
            .draw(in: NSBezierPath(roundedRect: face, xRadius: 19, yRadius: 19), angle: -90)
        let glyph = NSAttributedString(string: label, attributes: [
            .font: NSFont.systemFont(ofSize: label.count == 1 ? 54 : 40, weight: .medium),
            .foregroundColor: color(0x3A3330),
        ])
        let size = glyph.size()
        glyph.draw(at: NSPoint(x: face.midX - size.width / 2, y: face.midY - size.height / 2))
        x += width + gap
    }
}

// MARK: - Composite

func compose(_ scene: Scene, language: String, shot: Shot) -> Data {
    // No alpha channel (App Store Connect refuses screenshots with one), sRGB.
    let context = CGContext(data: nil, width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high

    drawDesktop()
    drawMenuBar(language: language, panelIsOpen: shot.panel != nil)
    drawCaption(scene, language: language)

    // Every window at its real size: the captures are 2×, like the canvas. The notes window peeks out
    // from behind the chat app, as on a desktop in use; both recede so the panel stands out.
    let notesSize = pixelSize(shot.notes)
    drawWindow(receded(shot.notes, light: scene.lightWindows), in: rect(x: 170, top: 430, width: notesSize.width, height: notesSize.height),
               blur: 50, offset: 18, opacity: 0.4)
    let chatSize = pixelSize(shot.chat)
    let chat = rect(x: canvas.width - chatSize.width - 190, top: 520, width: chatSize.width, height: chatSize.height)
    drawWindow(receded(shot.chat, light: scene.lightWindows), in: chat, blur: 90, offset: 32, opacity: 0.5)
    drawTrafficLights(on: chat)

    if scene.name == "open" {
        // The shortcut, on the desktop below the notes window.
        drawShortcutKeys(left: 210, midTop: 1590)
    }

    // The panel sits over the chat app, leaving its messages readable.
    let anchor = (x: chat.midX + 160, top: CGFloat(1060))
    if let panel = shot.panel {
        let size = pixelSize(panel)
        let x = min(anchor.x - size.width / 2, canvas.width - size.width - 100)
        let top = min(anchor.top, canvas.height - size.height - 90)
        drawWindow(panel, in: rect(x: x, top: top, width: size.width, height: size.height),
                   blur: 90, offset: 34, opacity: 0.6)
    }
    if let toast = shot.toast {
        let size = pixelSize(toast)
        drawWindow(toast, in: rect(x: anchor.x - size.width / 2, top: anchor.top + 260, width: size.width, height: size.height),
                   blur: 44, offset: 16, opacity: 0.4)
    }

    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

// MARK: - Main

guard FileManager.default.isExecutableFile(atPath: app) else {
    fatalError("Build the Debug app first: scripts/verify.sh --quick")
}
for language in languages {
    let folder = outputRoot.appending(path: language)
    try? FileManager.default.removeItem(at: folder)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for (index, scene) in scenes.enumerated() where sceneFilter?.contains(scene.name) ?? true {
        let shot = captureScene(scene, language: language)
        let file = folder.appending(path: "\(index + 1)-\(scene.name).png")
        try! compose(scene, language: language, shot: shot).write(to: file)
        print(file.path)
    }
}
