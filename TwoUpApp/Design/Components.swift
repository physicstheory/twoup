import SwiftUI

/// Chunky, rounded, springy. Label sits on an accent fill.
struct BigButtonStyle: ButtonStyle {
    var fill: Color = Palette.ochre
    var foreground: Color = Palette.onAccent

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(foreground)
            .padding(.vertical, 16)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(fill.opacity(isEnabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Outlined secondary button.
struct GhostButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.ink.opacity(0.35), lineWidth: 1.5))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Small pill used for amounts and toggles.
struct ChipStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(selected ? Palette.onAccent : Palette.ink)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(selected ? Palette.ochre : Palette.surfaceHigh, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Frosted panel that keeps text legible over the 3D scene.
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .background(Palette.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

/// Static film grain. Decorative, hidden from VoiceOver.
struct GrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x2545F4914F6CDD1D
            func next() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 10_000) / 10_000
            }
            for _ in 0..<2_200 {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 1.2, height: 1.2)
                context.fill(Path(rect), with: .color(.white.opacity(0.05 + next() * 0.07)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .blendMode(.overlay)
    }
}

enum Money {
    /// Play-money unit is "pennies", a nod to the coins used in the real game.
    static func short(_ n: Int) -> String { "\(n.formatted())p" }
    static func spoken(_ n: Int) -> String { n == 1 ? "1 penny" : "\(n.formatted()) pennies" }
    static func signed(_ n: Int) -> String { n >= 0 ? "+\(short(n))" : "−\(short(abs(n)))" }
}
