import Foundation
import TwoUpCore

/// Everything is stored on this device only, in UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    static let disclaimer = "Play money only. No real-money gambling. For entertainment and education."

    private let defaults: UserDefaults

    @Published var soundOn: Bool { didSet { defaults.set(soundOn, forKey: Key.sound) } }
    @Published var hapticsOn: Bool { didSet { defaults.set(hapticsOn, forKey: Key.haptics) } }
    @Published var hasAcceptedDisclaimer: Bool { didSet { defaults.set(hasAcceptedDisclaimer, forKey: Key.disclaimer) } }
    @Published var localBalance: Int { didSet { defaults.set(localBalance, forKey: Key.balance) } }

    private enum Key {
        static let sound = "soundOn"
        static let haptics = "hapticsOn"
        static let disclaimer = "hasAcceptedDisclaimer"
        static let balance = "localBalance"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        soundOn = defaults.object(forKey: Key.sound) as? Bool ?? true
        hapticsOn = defaults.object(forKey: Key.haptics) as? Bool ?? true
        hasAcceptedDisclaimer = defaults.bool(forKey: Key.disclaimer)
        localBalance = defaults.object(forKey: Key.balance) as? Int ?? GameState.startingBalance
    }

    func resetBalance() {
        localBalance = GameState.startingBalance
    }
}
