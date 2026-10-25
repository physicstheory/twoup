import UIKit

/// Everything the scene draws that isn't geometry. Each slot first looks for a bundled asset and
/// falls back to a procedural stand-in, so photoreal art can be dropped in with no code changes.
///
///   beer_garden_panorama   equirectangular 2:1 image (or HDRI) used as sky, backdrop and lighting
///   ground_dirt            seamless dirt/gravel texture for the ring
///   crowd_01 ... crowd_12  transparent PNG cut-outs of people, full length, facing the camera
///   coin_heads, coin_tails square coin face textures
enum SceneAssets {
    static func panorama() -> UIImage {
        UIImage(named: "beer_garden_panorama") ?? duskSky()
    }

    static func ground() -> UIImage {
        UIImage(named: "ground_dirt") ?? dirt()
    }

    static func crowdImages() -> [UIImage] {
        (1...12).compactMap { UIImage(named: String(format: "crowd_%02d", $0)) }
    }

    static func coinFace(heads: Bool) -> UIImage {
        UIImage(named: heads ? "coin_heads" : "coin_tails") ?? proceduralCoin(heads: heads)
    }

    // MARK: Procedural stand-ins

    private static func duskSky() -> UIImage {
        let size = CGSize(width: 1024, height: 512)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(hex: 0x1B1633), UIColor(hex: 0x4A2F5E), UIColor(hex: 0xB5502F), UIColor(hex: 0xF0A93B),
                          UIColor(hex: 0x2B1D16), UIColor(hex: 0x1A1210)].map(\.cgColor) as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                      locations: [0, 0.32, 0.46, 0.5, 0.5, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    private static func dirt() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        var rng = SystemRandomNumberGenerator()
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(hex: 0x8A4B2E).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<5_000 {
                let v = CGFloat.random(in: 0.55...1.1, using: &rng)
                UIColor(red: 0.54 * v, green: 0.29 * v, blue: 0.18 * v, alpha: 0.5).setFill()
                let r = CGFloat.random(in: 1...4, using: &rng)
                ctx.fill(CGRect(x: .random(in: 0...size.width, using: &rng), y: .random(in: 0...size.height, using: &rng),
                                width: r, height: r))
            }
        }
    }

    private static func proceduralCoin(heads: Bool) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIColor(hex: 0xC8923A).setFill()
            ctx.fill(rect)
            UIColor(hex: 0xE9BE62).setStroke()
            ctx.cgContext.setLineWidth(10)
            ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 18, dy: 18))
            ctx.cgContext.setLineWidth(3)
            ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 34, dy: 34))
            let text = heads ? "H" : "T"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 130, weight: .black),
                .foregroundColor: UIColor(hex: 0x6B4513)
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                      withAttributes: attributes)
        }
    }
}
