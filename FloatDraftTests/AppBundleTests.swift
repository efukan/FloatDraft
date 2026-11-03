import Foundation
import Testing

/// Guards the bundle-level contract from CLAUDE.md (bundle ID, menu-bar-only agent app).
struct AppBundleTests {
    private let info = Bundle.main.infoDictionary ?? [:]

    @Test func bundleIdentifierMatchesSpec() {
        #expect(Bundle.main.bundleIdentifier == "jp.efukan.FloatDraft")
    }

    @Test func runsAsMenuBarAgent() {
        #expect(info["LSUIElement"] as? Bool == true)
    }

    @Test func deploymentTargetIsSonoma() {
        #expect(info["LSMinimumSystemVersion"] as? String == "14.0")
    }

    @Test func privacyManifestIsBundled() {
        #expect(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
    }

    @Test func japaneseStringsAreBundled() throws {
        let path = try #require(Bundle.main.path(forResource: "ja", ofType: "lproj"))
        let japanese = try #require(Bundle(path: path))
        #expect(japanese.localizedString(forKey: "Copy & Clear  ⌘↩", value: nil, table: nil) == "コピーして消去  ⌘↩")
        #expect(japanese.localizedString(forKey: "%lld chars · %lld non-space · %lld lines", value: nil, table: nil)
            == "%1$lld 文字 · 空白除く %2$lld · %3$lld 行")
    }
}
