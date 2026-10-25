import SwiftUI
import TwoUpCore

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var clock = CommemorationDayClock(calendar: .autoupdatingCurrent)
    let settings: SettingsStore
    let haptics: HapticsService
    let sound: SoundService

    init(settings: SettingsStore? = nil) {
        let settings = settings ?? SettingsStore()
        self.settings = settings
        self.haptics = HapticsService(isEnabled: { settings.hapticsOn })
        self.sound = SoundService(isEnabled: { settings.soundOn })
    }
}
