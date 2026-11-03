#!/usr/bin/env bash
# FloatDraft verification gate. Run after every change; every milestone must pass this.
#
#   scripts/verify.sh            # full gate (generate, Debug build, tests, Release universal build, static checks)
#   scripts/verify.sh --quick    # generate, Debug build, tests only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="FloatDraft.xcodeproj"
SCHEME="FloatDraft"
DERIVED="build/DerivedData"
LOGS="build/logs"
QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

mkdir -p "$LOGS"

step() { printf '\n\033[1m▶ %s\033[0m\n' "$1"; }
pass() { printf '  \033[32m✔ %s\033[0m\n' "$1"; }
fail() { printf '  \033[31m✘ %s\033[0m\n' "$1"; exit 1; }

check_warnings() {
    local log="$1"
    local warnings
    warnings="$(grep -E '(^|: )warning: ' "$log" | sort -u || true)"
    if [[ -n "$warnings" ]]; then
        echo "$warnings"
        fail "warnings found in $log"
    fi
    pass "no warnings"
}

xcb() {
    local log="$1"; shift
    if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" -derivedDataPath "$DERIVED" "$@" >"$log" 2>&1; then
        grep -E 'error:' "$log" | sort -u | head -40 || true
        fail "xcodebuild $* failed (see $log)"
    fi
}

step "Generate project (XcodeGen)"
xcodegen generate --quiet
pass "FloatDraft.xcodeproj generated"

step "Debug build"
xcb "$LOGS/debug.log" -configuration Debug build
pass "build succeeded"
check_warnings "$LOGS/debug.log"

step "Unit tests"
# A running copy of the built app (e.g. left open for manual testing) collides with the test host
# (same bundle ID) and keeps xcodebuild from ever finishing. Quit it first.
if pkill -f "$ROOT/$DERIVED/Build/Products/.*/FloatDraft.app/Contents/MacOS/FloatDraft" 2>/dev/null; then
    echo "  (quit a running build of FloatDraft so the test host can run)"
    sleep 1
fi
xcb "$LOGS/test.log" -configuration Debug test
grep -E '^✔ Test run with' "$LOGS/test.log" | sed 's/^/  /' || true
pass "tests passed"
check_warnings "$LOGS/test.log"

if [[ $QUICK -eq 1 ]]; then
    printf '\n\033[32mQuick verification passed.\033[0m\n'
    exit 0
fi

step "Release build (universal)"
xcb "$LOGS/release.log" -configuration Release build
pass "build succeeded"
check_warnings "$LOGS/release.log"

APP="$DERIVED/Build/Products/Release/FloatDraft.app"
BIN="$APP/Contents/MacOS/FloatDraft"
PLIST="$APP/Contents/Info.plist"

step "Architectures"
ARCHS="$(lipo -archs "$BIN")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || fail "expected arm64 + x86_64, got: $ARCHS"
pass "$ARCHS"

step "Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" == "jp.efukan.FloatDraft" ]] || fail "bundle identifier"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$PLIST")" == "true" ]] || fail "LSUIElement must be true"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")" == "14.0" ]] || fail "LSMinimumSystemVersion must be 14.0"
[[ -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy" ]] || fail "PrivacyInfo.xcprivacy missing from bundle"
pass "bundle ID, LSUIElement, LSMinimumSystemVersion, privacy manifest"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSServices:0:NSMessage' "$PLIST")" == "editInFloatDraft" ]] || fail "NSServices (Edit in FloatDraft) missing"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSServices:0:NSSendTypes:0' "$PLIST")" == "public.utf8-plain-text" ]] || fail "NSServices must receive plain text"
! /usr/libexec/PlistBuddy -c 'Print :NSServices:0:NSReturnTypes' "$PLIST" >/dev/null 2>&1 || fail "NSServices must not return data to the sending app"
pass "Services menu: Edit in FloatDraft (receives plain text only)"

step "Entitlements (sandbox only)"
ENT="$(mktemp)"
codesign -d --entitlements - --xml "$BIN" 2>/dev/null >"$ENT"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$ENT")" == "true" ]] || fail "app sandbox not enabled"
KEYS="$(plutil -convert json -o - "$ENT" | /usr/bin/python3 -I -c 'import json,sys; print("\n".join(sorted(json.load(sys.stdin))))')"
rm -f "$ENT"
EXTRA="$(echo "$KEYS" | grep -v '^com.apple.security.app-sandbox$' || true)"
[[ -z "$EXTRA" ]] || { echo "$EXTRA"; fail "unexpected entitlements"; }
pass "only com.apple.security.app-sandbox"

step "Forbidden APIs (Accessibility / Input Monitoring / event taps)"
FORBIDDEN_SYMBOLS='_AXIsProcessTrusted|_AXIsProcessTrustedWithOptions|_AXUIElementCreate|_CGEventTapCreate|_CGEventTapCreateForPid|_CGEventTapCreateForPSN|_CGEventPost|_CGEventPostToPid|_CGEventPostToPSN|_CGPreflightListenEventAccess|_CGRequestListenEventAccess|_CGPreflightPostEventAccess|_CGRequestPostEventAccess|_IOHIDCheckAccess|_IOHIDRequestAccess'
HITS="$(nm -u "$BIN" 2>/dev/null | grep -E "($FORBIDDEN_SYMBOLS)\$" | sort -u || true)"
[[ -z "$HITS" ]] || { echo "$HITS"; fail "forbidden symbols linked"; }
pass "no forbidden symbols in binary"

FORBIDDEN_SOURCE='AXIsProcessTrusted|AXUIElement|CGEvent\.tapCreate|CGEventTapCreate|CGEventPost|\.post\(tap:|CGPreflightListenEventAccess|CGRequestListenEventAccess|IOHIDRequestAccess|addGlobalMonitorForEvents'
HITS="$(grep -rnE "$FORBIDDEN_SOURCE" FloatDraft || true)"
[[ -z "$HITS" ]] || { echo "$HITS"; fail "forbidden APIs referenced in sources"; }
pass "no forbidden APIs in sources"

step "Release bundle contents"
[[ -f "$APP/Contents/Resources/AppIcon.icns" ]] || fail "AppIcon.icns missing (app icon from AppIcon.icon)"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$PLIST" >/dev/null 2>&1 || fail "CFBundleIconName missing"
[[ -d "$APP/Contents/Resources/ja.lproj" ]] || fail "ja.lproj missing"
grep -q "Sindre Sorhus" "$APP/Contents/Resources/Credits.rtf" || fail "Credits.rtf must carry the KeyboardShortcuts license"
pass "app icon, Japanese localization, third-party license notice"
INTENTS="$APP/Contents/Resources/Metadata.appintents/extract.actionsdata"
[[ -f "$INTENTS" ]] || fail "App Intents metadata missing (Metadata.appintents)"
pass "App Intents metadata"
# App Store export re-signs the app but not resource bundles; one left with the build signature fails ITMS-90284.
SIGNED_BUNDLES="$(find "$APP/Contents/Resources" -name '*.bundle' -maxdepth 1 -exec test -d '{}/Contents/_CodeSignature' \; -print)"
[[ -z "$SIGNED_BUNDLES" ]] || { echo "$SIGNED_BUNDLES"; fail "resource bundles must not carry their own signature"; }
pass "resource bundles unsigned (sealed by the app)"
DEBUG_HOOKS="$(strings "$BIN" | grep -E -- 'showPanelOnLaunch|showSettingsOnLaunch|screenshotScene' || true)"
[[ -z "$DEBUG_HOOKS" ]] || { echo "$DEBUG_HOOKS"; fail "DEBUG-only launch hooks present in Release binary"; }
pass "no DEBUG-only launch hooks in Release"

step "Localization (every string has a Japanese translation)"
CATALOG="FloatDraft/Resources/Localizable.xcstrings"
SYNCED="$(mktemp -d)/Localizable.xcstrings"
cp "$CATALOG" "$SYNCED"
STRINGSDATA=()
while IFS= read -r file; do STRINGSDATA+=(--stringsdata "$file"); done < <(
    find "$DERIVED/Build/Intermediates.noindex/FloatDraft.build/Release/FloatDraft.build" -name '*.stringsdata')
[[ ${#STRINGSDATA[@]} -gt 0 ]] || fail "no .stringsdata found (SWIFT_EMIT_LOC_STRINGS)"
xcrun xcstringstool sync "$SYNCED" "${STRINGSDATA[@]}"
PROBLEMS="$(/usr/bin/python3 -I - "$SYNCED" <<'PY'
import json, sys
strings = json.load(open(sys.argv[1]))["strings"]
for key, entry in sorted(strings.items()):
    if entry.get("extractionState") == "stale":
        print(f"stale (no longer in code): {key!r}")
    elif entry.get("shouldTranslate") is not False and "ja" not in entry.get("localizations", {}):
        print(f"missing ja: {key!r}")
PY
)"
[[ -z "$PROBLEMS" ]] || { echo "$PROBLEMS"; fail "String Catalog out of date — run scripts/sync-strings.sh and translate"; }
pass "catalog matches code; all strings translated"
PROBLEMS="$(/usr/bin/python3 -I - "$INTENTS" FloatDraft/Resources/AppShortcuts.xcstrings <<'PY'
import json, sys
shortcuts = json.load(open(sys.argv[1])).get("autoShortcuts", [])
catalog = json.load(open(sys.argv[2]))["strings"]
phrases = {p["key"] for s in shortcuts for p in s.get("phraseTemplates", [])}
if not phrases:
    print("no App Shortcut phrases in the App Intents metadata")
for key in sorted(phrases):
    if "ja" not in catalog.get(key, {}).get("localizations", {}):
        print(f"missing ja phrase: {key!r}")
for key in sorted(set(catalog) - phrases):
    print(f"stale phrase (no longer in code): {key!r}")
PY
)"
[[ -z "$PROBLEMS" ]] || { echo "$PROBLEMS"; fail "AppShortcuts.xcstrings out of date — translate the App Shortcut phrases"; }
pass "App Shortcut phrases translated"

step "Panel tooltips"
# AppKit tooltips (.help) never appear in the non-activating panel; panel views must use .hoverTooltip.
HITS="$(grep -rnE '\.help\(' FloatDraft/Sources/Panel FloatDraft/Sources/History || true)"
[[ -z "$HITS" ]] || { echo "$HITS"; fail ".help in panel views — use .hoverTooltip (AppKit tooltips do not show while inactive)"; }
pass "panel views use hoverTooltip"

step "Pasteboard is write-only (E18)"
# One exception: the Services menu handler reads the pasteboard the system hands it for that request
# (the text the user selected and sent), never the general clipboard.
SERVICES_FILE="FloatDraft/Sources/Integrations/ServicesProvider.swift"
[[ -f "$SERVICES_FILE" ]] || fail "$SERVICES_FILE missing (update this check if it moved)"
PB_READS='\.(string|data|propertyList)\(forType:|\.(readObjects|canReadObject|canReadItem|availableType)\(|\.(pasteboardItems|types)\b'
HITS="$(grep -rnE "$PB_READS" FloatDraft | grep -v "^$SERVICES_FILE:" || true)"
[[ -z "$HITS" ]] || { echo "$HITS"; fail "programmatic pasteboard reads found"; }
pass "no programmatic pasteboard reads outside the Services handler"
HITS="$(grep -nE '\.general\b|NSPasteboard\(' "$SERVICES_FILE" || true)"
[[ -z "$HITS" ]] || { echo "$HITS"; fail "$SERVICES_FILE may read only the pasteboard the service is given"; }
pass "Services handler never opens the general clipboard"

printf '\n\033[32mAll verification steps passed.\033[0m\n'
