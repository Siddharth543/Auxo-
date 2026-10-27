import SwiftUI
import CoreGraphics

public enum HexColor {
    /// Parses "#RRGGBB" or "RRGGBB". Invalid input gives black.
    public static func rgb(_ hex: String) -> (r: Int, g: Int, b: Int) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return (0, 0, 0) }
        return (Int((value >> 16) & 0xFF), Int((value >> 8) & 0xFF), Int(value & 0xFF))
    }

    public static func isValid(_ hex: String) -> Bool {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        return cleaned.count == 6 && UInt32(cleaned, radix: 16) != nil
    }

    public static func string(r: Int, g: Int, b: Int) -> String {
        func clamp(_ v: Int) -> Int { min(255, max(0, v)) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }

    /// Linear blend from `a` (t = 0) to `b` (t = 1).
    public static func mix(_ a: String, _ b: String, _ t: Double) -> String {
        let x = rgb(a), y = rgb(b)
        func blend(_ p: Int, _ q: Int) -> Int { Int((Double(p) + (Double(q) - Double(p)) * t).rounded()) }
        return string(r: blend(x.r, y.r), g: blend(x.g, y.g), b: blend(x.b, y.b))
    }

    /// "#RRGGBB" for a SwiftUI color (used by the custom-theme color picker).
    public static func string(from color: Color) -> String? {
        let resolved = color.resolve(in: EnvironmentValues())
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = resolved.cgColor.converted(to: space, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3 else {
            return nil
        }
        return string(r: Int((components[0] * 255).rounded()),
                      g: Int((components[1] * 255).rounded()),
                      b: Int((components[2] * 255).rounded()))
    }
}

public extension Color {
    init(hex: String) {
        let c = HexColor.rgb(hex)
        self.init(.sRGB, red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255, opacity: 1)
    }
}
