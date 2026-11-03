#!/usr/bin/env bash
# Adds strings found in the code to Localizable.xcstrings (and marks removed ones stale).
# Run after adding or changing UI text, then add the Japanese translations it reports missing.
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED="build/DerivedData"
xcodegen generate --quiet
xcodebuild -project FloatDraft.xcodeproj -scheme FloatDraft -configuration Debug -derivedDataPath "$DERIVED" build \
    >build/logs/sync-strings.log 2>&1 || { echo "build failed (see build/logs/sync-strings.log)"; exit 1; }
ARGS=()
while IFS= read -r file; do ARGS+=(--stringsdata "$file"); done < <(
    find "$DERIVED/Build/Intermediates.noindex/FloatDraft.build/Debug/FloatDraft.build" -name '*.stringsdata')
xcrun xcstringstool sync FloatDraft/Resources/Localizable.xcstrings "${ARGS[@]}"
echo "Synced. Translate any new entries (Xcode's String Catalog editor, or edit the JSON)."
