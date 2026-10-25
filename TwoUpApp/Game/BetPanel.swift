import SwiftUI
import TwoUpCore

struct BetPanel: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                switch model.state.phase {
                case .betting:
                    if model.isSpinner { SpinnerControls(model: model) } else { FadeControls(model: model) }
                    SideBetControls(model: model)
                    if model.mode == .practice { RulesHint() }
                case .tossing:
                    StatusLine(text: "Coins in the air…", symbol: "arrow.up.circle")
                case .resolved:
                    StatusLine(text: "Settling up…", symbol: "checkmark.circle")
                }
            }
        }
    }
}

private struct StatusLine: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
    }
}

// MARK: - Spinner

private struct SpinnerControls: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Your spin: stake on heads")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("Pays 1:1")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GameViewModel.stakeChoices, id: \.self) { value in
                        Button(Money.short(value)) { model.setStake(value) }
                            .buttonStyle(ChipStyle(selected: model.state.bets.spinnerStake == value))
                            .disabled(value > model.available + model.state.bets.spinnerStake)
                    }
                    Button("Max") { model.setStake(model.local.balance - sideTotal) }
                        .buttonStyle(ChipStyle(selected: model.state.bets.spinnerStake == model.local.balance - sideTotal
                                               && model.state.bets.spinnerStake > 0))
                        .disabled(model.local.balance <= 0)
                }
            }

            coverage

            Button(model.state.bets.spinnerStake > 0
                   ? "Toss for \(Money.short(model.state.bets.spinnerAtRisk))" : "Pick a stake") {
                model.toss()
            }
            .buttonStyle(BigButtonStyle())
            .disabled(model.state.bets.spinnerStake == 0)
            .accessibilityHint("Tosses both coins")
        }
    }

    private var sideTotal: Int {
        model.state.bets.sideBets.filter { $0.playerID == model.local.id }.reduce(0) { $0 + $1.stake }
    }

    private var coverage: some View {
        let stake = model.state.bets.spinnerStake
        let covered = stake - model.uncovered
        return VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: stake == 0 ? 0 : Double(covered), total: Double(max(stake, 1)))
                .tint(Palette.gum)
            Text(stake == 0 ? "The ring covers your stake. You only risk what's covered."
                 : "Ring has covered \(Money.short(covered)) of \(Money.short(stake)). You risk \(Money.short(covered)).")
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Fading

private struct FadeControls: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        let spinner = model.state.spinner
        let stake = model.state.bets.spinnerStake
        VStack(spacing: 10) {
            HStack {
                Text("\(spinner.name) is spinning for \(Money.short(stake)) on heads")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
            }

            HStack(spacing: 8) {
                fadeButton(10)
                fadeButton(50)
                Button("Cover rest") { model.fade(min(model.uncovered, model.available)) }
                    .buttonStyle(ChipStyle())
                    .disabled(model.uncovered == 0 || model.available == 0)
            }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(statusText)
        }
    }

    private func fadeButton(_ amount: Int) -> some View {
        Button("Fade \(amount)") { model.fade(amount) }
            .buttonStyle(ChipStyle())
            .disabled(model.uncovered == 0 || amount > model.available)
    }

    private var statusText: String {
        let mine = model.localFade
        if model.uncovered == 0 {
            return mine > 0 ? "Covered. You're fading \(Money.short(mine)) (pays 1:1 if it lands tails)."
                            : "Covered by others. Waiting for the toss."
        }
        return "\(Money.short(model.uncovered)) still to cover. Fading means you win if the spinner loses."
    }
}

// MARK: - Side bets

private struct SideBetControls: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Side bets")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                Spacer()
                ForEach(GameViewModel.sideStakeChoices, id: \.self) { value in
                    Button("\(value)") { model.sideStake = value }
                        .buttonStyle(ChipStyle(selected: model.sideStake == value))
                        .accessibilityLabel("Side bet stake \(Money.spoken(value))")
                }
            }
            HStack(spacing: 8) {
                ForEach(SideBetKind.allCases, id: \.self) { kind in
                    SideBetButton(kind: kind, stake: model.sideBetStake(kind),
                                  enabled: model.sideBetStake(kind) > 0 || model.sideStake <= model.available) {
                        model.toggleSideBet(kind)
                    }
                }
            }
        }
    }
}

private struct SideBetButton: View {
    let kind: SideBetKind
    let stake: Int
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(kind.rawValue.capitalized)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                Text("pays \(kind.payout.label)")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                if stake > 0 {
                    Text(Money.short(stake))
                        .font(.system(.caption2, design: .rounded, weight: .black))
                }
            }
            .foregroundStyle(stake > 0 ? Palette.onAccent : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(stake > 0 ? Palette.ochre : Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.hairline))
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .accessibilityLabel("\(kind.rawValue) side bet, pays \(kind.payout.label)")
        .accessibilityValue(stake > 0 ? "\(Money.spoken(stake)) placed" : "not placed")
        .accessibilityHint(stake > 0 ? "Double tap to remove" : "Double tap to place")
    }
}

private struct RulesHint: View {
    var body: some View {
        Text("Two heads: spinner wins. Two tails: spinner loses. One of each: toss again. Five odds in a row and the spinner loses.")
            .font(.caption)
            .foregroundStyle(Palette.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
