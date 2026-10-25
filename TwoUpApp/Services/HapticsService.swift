import UIKit

@MainActor
final class HapticsService {
    private let isEnabled: () -> Bool
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
    }

    func tossStart() { guard isEnabled() else { return }; impact.impactOccurred(intensity: 0.8) }
    func coinLand() { guard isEnabled() else { return }; rigid.impactOccurred(intensity: 0.9) }
    func win() { guard isEnabled() else { return }; notification.notificationOccurred(.success) }
    func lose() { guard isEnabled() else { return }; notification.notificationOccurred(.warning) }
    func tap() { guard isEnabled() else { return }; selection.selectionChanged() }
}
