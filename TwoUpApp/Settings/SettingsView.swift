import SwiftUI
import TwoUpCore

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Text(SettingsStore.disclaimer)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }

            Section("Feel") {
                Toggle("Sound", isOn: $settings.soundOn)
                Toggle("Haptics", isOn: $settings.hapticsOn)
            }

            Section {
                LabeledContent("Your balance", value: Money.short(settings.localBalance))
                Button("Reset balance to \(Money.short(GameState.startingBalance))") { confirmReset = true }
            } header: {
                Text("Pennies")
            } footer: {
                Text("Pennies are play money. They can't be bought, sold or cashed out, and a reset is always free.")
            }

            Section("Support") {
                Link(destination: URL(string: "https://www.gamblinghelponline.org.au")!) {
                    Label("Gambling Help Online", systemImage: "heart.text.square")
                }
                .accessibilityHint("Opens gamblinghelponline.org.au in your browser")
            }

            Section {
                NavigationLink("About Two-Up") { AboutView() }
            }

            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            } footer: {
                Text("Everything stays on this device. No accounts, no tracking.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .confirmationDialog("Reset your balance?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset to \(Money.short(GameState.startingBalance))") { settings.resetBalance() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
