import SwiftUI
import UIKit

extension Color {
    /// A colour that switches with light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

/// Outback dusk: red earth, ochre, gum leaf, and a violet horizon for a bit of edge.
/// Text pairs are chosen for at least 4.5:1 contrast in both appearances.
enum Palette {
    static let background   = Color(light: 0xF6EBDD, dark: 0x15110F)
    static let surface      = Color(light: 0xFFF8EE, dark: 0x221B17)
    static let surfaceHigh  = Color(light: 0xFFFFFF, dark: 0x302621)
    static let ink          = Color(light: 0x2A1E17, dark: 0xF6EBDD)
    static let inkSoft      = Color(light: 0x66503F, dark: 0xC4B3A0)
    static let ochre        = Color(light: 0xA45A0C, dark: 0xF0A93B)
    static let terracotta   = Color(light: 0xA83F28, dark: 0xF0795F)
    static let gum          = Color(light: 0x2F6148, dark: 0x8FC9A5)
    static let dusk         = Color(light: 0x57457A, dark: 0xBBA9E6)
    static let onAccent     = Color(light: 0xFFFFFF, dark: 0x15110F)
    static let hairline     = Color(light: 0x2A1E17, dark: 0xF6EBDD).opacity(0.14)

    /// Decorative only; never put small text straight on it.
    static let horizon = LinearGradient(
        colors: [Color(hex: 0x3B2A5C), Color(hex: 0xA8452B), Color(hex: 0xF0A93B)],
        startPoint: .top, endPoint: .bottom)
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}
