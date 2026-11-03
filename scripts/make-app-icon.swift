// Writes the FloatDraft app icon as an Icon Composer document (AppIcon.icon): one SVG per layer plus icon.json.
//
//   swift scripts/make-app-icon.swift
//
// Xcode renders the Liquid Glass icon (default, dark, tinted, clear) from it and generates the flat icons
// for earlier macOS versions, so there is no separate AppIcon asset. Open the result in Icon Composer
// to preview it; edit this script rather than the document so the two stay in sync.
//
// Drawn entirely with paths (no SF Symbols: their license excludes app icons).
// Motif: the small FloatDraft panel floating over another app's larger window, with a pencil
// writing in it. Colors come from the Paper theme (PanelPalette.paper) and its coral accent.
import Foundation

let iconURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "FloatDraft/Resources/AppIcon.icon")
let assetsURL = iconURL.appending(path: "Assets")

/// Every layer covers the whole 1024pt canvas (which the system masks to the icon shape).
/// The artwork is laid out on a 100-unit grid over it, y growing downward.
func layer(_ shapes: String) -> String {
    """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 100 100">
    \(shapes)
    </svg>

    """
}

/// A rectangle with only its top corners rounded: title bars and the panel header.
func topRoundedRect(x: Double, y: Double, width: Double, height: Double, radius: Double) -> String {
    "M\(x + radius) \(y) H\(x + width - radius) Q\(x + width) \(y) \(x + width) \(y + radius) "
        + "V\(y + height) H\(x) V\(y + radius) Q\(x) \(y) \(x + radius) \(y) Z"
}

// Another app's window, much larger than the panel: coral, with a title bar and three lines.
let window = layer("""
<rect x="8" y="10" width="76" height="62" rx="8" fill="#E8825B"/>
<path d="\(topRoundedRect(x: 8, y: 10, width: 76, height: 11, radius: 8))" fill="#F0997B"/>
<circle cx="14.5" cy="15.5" r="1.8" fill="#FAECE7"/>
<circle cx="20" cy="15.5" r="1.8" fill="#FAECE7"/>
<circle cx="25.5" cy="15.5" r="1.8" fill="#FAECE7"/>
<rect x="15" y="28" width="34" height="4" rx="2" fill="#F5C4B3"/>
<rect x="15" y="36" width="44" height="4" rx="2" fill="#F5C4B3"/>
<rect x="15" y="44" width="16" height="4" rx="2" fill="#F5C4B3"/>
""")

// The FloatDraft panel floating over it, in Paper colors: header, separator, two lines of text.
// Its shadow comes from the group's glass settings below.
let panel = layer("""
<rect x="36" y="44" width="54" height="40" rx="8.5" fill="#FFFDF8"/>
<path d="\(topRoundedRect(x: 36, y: 44, width: 54, height: 10.5, radius: 8.5))" fill="#F1EFE8"/>
<rect x="36" y="54.5" width="54" height="1" fill="#D3D1C7"/>
<rect x="43" y="61.5" width="33" height="4.8" rx="2.4" fill="#D3D1C7"/>
<rect x="43" y="71" width="18" height="4.8" rx="2.4" fill="#D3D1C7"/>
""")

// Pencil writing at the end of the second line (tip at 61, 73.4), drawn with its tip at -12, 0.
let pencil = layer("""
<g transform="translate(68.35 67.2) rotate(-40) scale(0.8)">
<rect x="0" y="-7" width="34" height="14" fill="#2C2C2A"/>
<rect x="34" y="-7" width="8" height="14" rx="2" fill="#D85A30"/>
<path d="M0 -7 L-12 0 L0 7 Z" fill="#F5C4B3"/>
<path d="M-7 -3 L-12 0 L-7 3 Z" fill="#2C2C2A"/>
</g>
""")

/// One group per layer so each casts its own shadow on the ones behind. Opaque (no translucency):
/// the panel must read as solid paper over the window.
func group(_ name: String) -> [String: Any] {
    [
        "layers": [["image-name": "\(name).svg", "name": name]],
        "shadow": ["kind": "neutral", "opacity": 0.5],
        "translucency": ["enabled": false, "value": 0.5],
    ]
}

let manifest: [String: Any] = [
    // Background: a slightly deeper paper tone than the panel (#EAE6DD), so the icon keeps an edge on white.
    "fill": ["solid": "extended-srgb:0.91765,0.90196,0.86667,1.00000"],
    // Front to back.
    "groups": [group("pencil"), group("panel"), group("window")],
    "supported-platforms": ["squares": ["macOS"]],
]

try? FileManager.default.removeItem(at: iconURL)
try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
for (name, svg) in [("window", window), ("panel", panel), ("pencil", pencil)] {
    try svg.write(to: assetsURL.appending(path: "\(name).svg"), atomically: true, encoding: .utf8)
}
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconURL.appending(path: "icon.json"))
print("Wrote \(iconURL.path)")
