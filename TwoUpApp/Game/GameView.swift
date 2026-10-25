import SwiftUI
import TwoUpCore

struct GameView: View {
    @StateObject private var model: GameViewModel
    @StateObject private var scene = CoinSceneController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mode: GameMode, env: AppEnvironment) {
        _model = StateObject(wrappedValue: GameViewModel.local(mode: mode, env: env))
    }

    var body: some View {
        ZStack {
            GameSceneView(controller: scene)
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel(model.coinsDescription)
                .accessibilityAddTraits(.updatesFrequently)

            // Soft vignette so overlays stay readable on top of the scene.
            LinearGradient(colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.65)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                TopBar(model: model, close: { dismiss() })
                HistoryStrip(history: model.state.history, players: model.state.players)
                Spacer(minLength: 0)
                if let banner = model.banner {
                    BannerView(banner: banner)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                }
                PlayersStrip(state: model.state)
                BetPanel(model: model)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: model.banner)
        }
        .preferredColorScheme(.dark)   // the scene is a dusk scene in both appearances
        .onAppear {
            model.animator = scene
            model.start()
        }
        .onDisappear { model.stop() }
        .alert("Out of pennies", isPresented: $model.showResetOffer) {
            Button("Reset to 1,000") { model.resetBalance() }
            Button("Not now", role: .cancel) { model.dismissResetOffer() }
        } message: {
            Text("Pennies are play money and a reset is always free.")
        }
        .alert("Heads up", isPresented: .init(get: { model.errorMessage != nil },
                                              set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @ObservedObject var model: GameViewModel
    let close: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Leave game")

            Text(model.mode.title.uppercased())
                .font(.system(.caption, design: .rounded, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            OddsStreakView(streak: model.state.oddsStreak)

            Text(Money.short(model.local.balance))
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.vertical, 10).padding(.horizontal, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .contentTransition(.numericText())
                .accessibilityLabel("Your balance: \(Money.spoken(model.local.balance))")
        }
    }
}

struct OddsStreakView: View {
    let streak: Int
    private let limit = TwoUpEngine<SystemRandomNumberGenerator>.maxOddsInARow

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<limit, id: \.self) { i in
                Circle()
                    .fill(i < streak ? Palette.ochre : .white.opacity(0.22))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Odds streak: \(streak) of \(limit). \(limit) odds in a row and the spinner loses.")
    }
}

// MARK: - History

struct HistoryStrip: View {
    let history: [HistoryEntry]
    let players: [PlayerState]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if history.isEmpty {
                        Text("No tosses yet")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                    }
                    ForEach(Array(history.enumerated()), id: \.offset) { index, entry in
                        Chip(outcome: entry.toss.outcome).id(index)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial, in: Capsule())
            .onChange(of: history.count) { _, count in
                if count > 0 { proxy.scrollTo(count - 1, anchor: .trailing) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last \(history.count) tosses, most recent last: " + spoken)
    }

    private var spoken: String {
        history.isEmpty ? "none" : history.map { word($0.toss.outcome) }.joined(separator: ", ")
    }

    private func word(_ o: TossOutcome) -> String {
        switch o { case .heads: return "heads"; case .tails: return "tails"; case .odds: return "odds" }
    }

    private struct Chip: View {
        let outcome: TossOutcome

        var body: some View {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(outcome == .odds ? Color.white : Palette.onAccent)
                .frame(width: 30, height: 24)
                .background(fill, in: Capsule())
        }

        private var label: String {
            switch outcome { case .heads: return "HH"; case .tails: return "TT"; case .odds: return "HT" }
        }

        private var fill: Color {
            switch outcome {
            case .heads: return Palette.ochre
            case .tails: return Palette.terracotta
            case .odds: return .white.opacity(0.25)
            }
        }
    }
}

// MARK: - Banner

private struct BannerView: View {
    let banner: ResultBanner

    var body: some View {
        VStack(spacing: 4) {
            Text(banner.title)
                .font(.system(.title, design: .rounded, weight: .black))
            Text(banner.detail)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 14).padding(.horizontal, 22)
        .background(tint.opacity(0.88), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.25)))
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch banner.tone {
        case .win: return Color(hex: 0x2F6148)
        case .lose: return Color(hex: 0x8F3521)
        case .neutral: return Color(hex: 0x3B2A5C)
        }
    }
}

// MARK: - Players

struct PlayersStrip: View {
    let state: GameState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(state.players.enumerated()), id: \.element.id) { index, player in
                    PlayerBadge(player: player, isSpinner: index == state.spinnerIndex)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }
}

private struct PlayerBadge: View {
    let player: PlayerState
    let isSpinner: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(String(player.name.prefix(1)))
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: Circle())
                .overlay(Circle().strokeBorder(isSpinner ? Palette.ochre : .white.opacity(0.3), lineWidth: isSpinner ? 3 : 1))
            Text(player.name)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(Money.short(player.balance))
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(minWidth: 60)
        .padding(.vertical, 6).padding(.horizontal, 6)
        .background(.black.opacity(isSpinner ? 0.5 : 0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(player.isLocal ? "You" : player.name), \(Money.spoken(player.balance))\(isSpinner ? ", the spinner" : "")")
    }

    /// Stable colour per player from the earthy palette.
    private var color: Color {
        let options: [UInt32] = [0xA83F28, 0x2F6148, 0x57457A, 0xA45A0C, 0x2D5A6B, 0x7A4B2A, 0x6B2F4F, 0x4A5D23]
        let hash = player.id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Color(hex: options[hash % options.count])
    }
}
