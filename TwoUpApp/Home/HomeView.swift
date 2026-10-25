import SwiftUI
import TwoUpCore

struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var activeGame: GameMode?
    @State private var showSettings = false
    @State private var showDebug = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let snapshot = HomeViewModel.snapshot(clock: env.clock)
            ZStack {
                background(for: snapshot)
                ScrollView {
                    VStack(spacing: 28) {
                        topBar
                        hero(snapshot)
                        actions(snapshot)
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 560)
                }
            }
        }
        .fullScreenCover(item: $activeGame) { mode in
            GameView(mode: mode, env: env)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        #if DEBUG
        .sheet(isPresented: $showDebug) { DebugMenu() }
        #endif
    }

    // MARK: Pieces

    private func background(for snapshot: HomeSnapshot) -> some View {
        ZStack {
            Palette.background
            RadialGradient(colors: [Palette.ochre.opacity(0.35), .clear],
                           center: .init(x: 0.5, y: 0.0), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Palette.dusk.opacity(0.30), .clear],
                           center: .init(x: 1.0, y: 1.0), startRadius: 10, endRadius: 480)
            GrainOverlay()
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Text("TWO-UP")
                .font(.system(.headline, design: .rounded, weight: .black))
                .tracking(3)
                .foregroundStyle(Palette.ink)
                .padding(.vertical, 8).padding(.horizontal, 14)
                .background(Palette.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.hairline))
                #if DEBUG
                .onTapGesture(count: 5) { showDebug = true }   // hidden debug menu
                #endif
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Palette.hairline))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func hero(_ snapshot: HomeSnapshot) -> some View {
        switch snapshot.kind {
        case .countdown(let c):
            CountdownHero(countdown: c, dateLine: snapshot.dateLine, spoken: snapshot.spokenCountdown)
        case .commemorationDay:
            CommemorationDayHero(dateLine: snapshot.dateLine, spoken: snapshot.spokenCountdown)
        }
    }

    @ViewBuilder
    private func actions(_ snapshot: HomeSnapshot) -> some View {
        VStack(spacing: 12) {
            if snapshot.kind == .commemorationDay {
                Button("Play Two-Up") { activeGame = .commemorationDay }
                    .buttonStyle(BigButtonStyle())
                Button("Practice") { activeGame = .practice }
                    .buttonStyle(GhostButtonStyle())
            } else {
                Button("Practice") { activeGame = .practice }
                    .buttonStyle(BigButtonStyle())
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(SettingsStore.disclaimer)
                .font(.footnote)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
            #if DEBUG
            if env.clock.isDebugDateActive {
                Text("Debug date active")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.terracotta)
            }
            #endif
        }
        .padding(.top, 4)
    }
}

// MARK: - Countdown

private struct CountdownHero: View {
    let countdown: Countdown
    let dateLine: String
    let spoken: String

    @ScaledMetric(relativeTo: .largeTitle) private var daysSize: CGFloat = 112
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: -4) {
                Text("\(countdown.days)")
                    .font(.system(size: daysSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(countsDown: true))
                Text(countdown.days == 1 ? "DAY" : "DAYS")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(Palette.ochre)
            }

            HStack(spacing: 10) {
                UnitTile(value: countdown.hours, label: "hrs")
                UnitTile(value: countdown.minutes, label: "min")
                UnitTile(value: countdown.seconds, label: "sec")
            }

            VStack(spacing: 2) {
                Text("Until 25 April")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(dateLine)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.vertical, 12)
        .animation(reduceMotion ? nil : .snappy, value: countdown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct UnitTile: View {
    let value: Int
    let label: String
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 38

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText(countsDown: true))
            Text(label.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(2)
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.hairline))
    }
}

private struct CommemorationDayHero: View {
    let dateLine: String
    let spoken: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 54))
                .foregroundStyle(Palette.ochre)
                .accessibilityHidden(true)
            Text("25 April")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(Palette.ink)
            Text(dateLine)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            Text("Lest we forget.")
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 6)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}
