import KeyboardShortcuts
import ServiceManagement
import SwiftUI

/// Contents of the Settings window (D5): global shortcut, launch at login, open position.
struct SettingsView: View {
    @Bindable var preferences: PanelPreferences
    let loginItem: LoginItemController

    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Show or hide the draft panel:", name: .togglePanel)
            }

            Section("General") {
                Toggle("Launch FloatDraft at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.needsApproval {
                    HStack {
                        Text("Allow FloatDraft in System Settings › General › Login Items.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
                if let error = loginItem.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                Picker("Open the panel at", selection: $preferences.positionMode) {
                    Text("Mouse cursor").tag(PanelPositionMode.mouseCursor)
                    Text("Last dragged position").tag(PanelPositionMode.rememberLastPosition)
                }
                Toggle("Keep the panel open when switching Spaces", isOn: $preferences.staysOpenAcrossSpaces)
                Text("Swiping to another desktop (or ⌃← / ⌃→) keeps the panel in front, so you can check something and keep typing. Turn off to close it as if you clicked elsewhere.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Color mode", selection: $preferences.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.name).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                LabeledContent("Theme") {
                    ThemePicker(selection: $preferences.theme, appearanceMode: preferences.appearanceMode)
                }
                if preferences.theme == .graphite {
                    Text("The Graphite theme is always dark.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $preferences.editorFontSize, in: PanelPreferences.fontSizeRange, step: 1) {
                    LabeledContent("Text size", value: "\(Int(preferences.editorFontSize)) pt")
                }
                Toggle("Use a monospaced font", isOn: $preferences.usesMonospacedFont)
                Text("In the panel, ⌘+ and ⌘− change the text size and ⌘0 resets it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Background opacity and pinning are in the panel itself (the slider icon in its header), so you can preview them live.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { loginItem.refresh() }
    }
}
