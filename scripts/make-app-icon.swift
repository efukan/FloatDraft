// Writes the FloatDraft app icon as an Icon Composer document (AppIcon.icon): one SVG per layer plus icon.json.
//
//   swift scripts/make-app-icon.swift
//
// Xcode renders the Liquid Glass icon (default, dark, tinted, clear) from it and generates the flat icons
// for earlier macOS versions, so there is no separate AppIcon asset. Open the result in Icon Composer
// to preview it; edit this script rather than the document so the two stay in sync.
//
// Drawn entirely with paths (no SF Symbols: their license excludes app icons).
// Motif: the FloatDraft panel floating over another app's window, with a pencil writing in it. The whole icon
// is that window, so the panel can be large enough to read at small sizes. Colors come from the Paper theme
// (PanelPalette.paper) and its coral accent.
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

// Another app's window, which fills the icon: the background below is its coral body, and this is its title bar.
let window = layer("""
<rect x="0" y="0" width="100" height="22" fill="#F3A483"/>
<circle cx="16" cy="12" r="3" fill="#FDF0EA"/>
<circle cx="26" cy="12" r="3" fill="#FDF0EA"/>
<circle cx="36" cy="12" r="3" fill="#FDF0EA"/>
""")

// The FloatDraft panel floating over it, in Paper colors: header, separator, two lines of text.
// Its shadow comes from the group's glass settings below.
let panel = layer("""
<rect x="16" y="37" width="70" height="52" rx="10" fill="#FFFDF8"/>
<path d="\(topRoundedRect(x: 16, y: 37, width: 70, height: 12.5, radius: 10))" fill="#EFEBE1"/>
<rect x="16" y="49.5" width="70" height="1" fill="#D3D1C7"/>
<rect x="25" y="58" width="44" height="6.4" rx="3.2" fill="#C9C6BA"/>
<rect x="25" y="70.4" width="26" height="6.4" rx="3.2" fill="#C9C6BA"/>
""")

// Pencil writing at the end of the second line (tip at 51, 73.6), drawn with its tip at -12, 0.
// A warm brown rather than black, so it belongs with the paper; a pale cap, as coral would melt into the window.
let pencil = layer("""
<g transform="translate(60.19 65.89) rotate(-40)">
<rect x="0" y="-7" width="34" height="14" fill="#43362F"/>
<rect x="34" y="-7" width="8" height="14" rx="2" fill="#F9D9C9"/>
<path d="M0 -7 L-12 0 L0 7 Z" fill="#F5C4B3"/>
<path d="M-7 -3 L-12 0 L-7 3 Z" fill="#43362F"/>
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

func verticalGradient(_ top: String, _ bottom: String) -> [String: Any] {
    ["linear-gradient": [top, bottom], "orientation": ["start": ["x": 0.5, "y": 0.0], "stop": ["x": 0.5, "y": 1.0]]]
}

let manifest: [String: Any] = [
    // Background: the window's coral (#EC8660 to #E0714A), which gives the icon a clear edge on white and on dark.
    // The dark icon gets a deeper coral (#A9553A to #8C4029); left alone, the system turns the fill black.
    "fill-specializations": [
        ["value": verticalGradient("extended-srgb:0.92549,0.52549,0.37647,1.00000", "extended-srgb:0.87843,0.44314,0.29020,1.00000")],
        ["appearance": "dark",
         "value": verticalGradient("extended-srgb:0.66275,0.33333,0.22745,1.00000", "extended-srgb:0.54902,0.25098,0.16078,1.00000")],
    ],
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
