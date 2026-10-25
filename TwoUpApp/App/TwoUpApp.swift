import SwiftUI

@main
struct TwoUpApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .environmentObject(env.settings)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        HomeView()
            .fullScreenCover(isPresented: .init(get: { !settings.hasAcceptedDisclaimer },
                                                set: { _ in })) {
                DisclaimerView()
            }
    }
}

/// Shown once, before anything else.
struct DisclaimerView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Palette.ochre)
                    .accessibilityHidden(true)
                Text("Before you play")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(Palette.ink)
                Text(SettingsStore.disclaimer)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Pennies in this app have no value, can't be bought, and can't be cashed out. "
                     + "If gambling is a worry for you or someone you know, Gambling Help Online offers free, confidential support.")
                    .font(.body)
                    .foregroundStyle(Palette.inkSoft)
                Link("Gambling Help Online", destination: URL(string: "https://www.gamblinghelponline.org.au")!)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.gum)
                    .frame(minHeight: 44)
                Spacer()
                Button("I understand") { settings.hasAcceptedDisclaimer = true }
                    .buttonStyle(BigButtonStyle())
            }
            .padding(24)
        }
    }
}
