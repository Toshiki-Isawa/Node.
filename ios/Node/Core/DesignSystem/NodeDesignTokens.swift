import SwiftUI

// MARK: - Node. Design Tokens (from design/colors_and_type.css)

enum NodeColor {
    // Base — oklch values mapped to sRGB
    static let void = Color(red: 0.039, green: 0.043, blue: 0.039)       // --c-void
    static let graphite = Color(red: 0.078, green: 0.086, blue: 0.102) // --c-graphite
    static let charcoal = Color(red: 0.114, green: 0.122, blue: 0.110) // --c-charcoal
    static let bark = Color(red: 0.153, green: 0.165, blue: 0.149)     // --c-bark
    static let stone = Color(red: 0.227, green: 0.239, blue: 0.224)    // --c-stone
    static let fossil = Color(red: 0.325, green: 0.341, blue: 0.318)   // --c-fossil

    // Foreground
    static let bone = Color(red: 0.925, green: 0.914, blue: 0.875)     // --c-bone
    static let paper = Color(red: 0.839, green: 0.827, blue: 0.784)    // --c-paper
    static let fog = Color(red: 0.678, green: 0.690, blue: 0.651)      // --c-fog
    static let mist = Color(red: 0.529, green: 0.541, blue: 0.510)     // --c-mist

    // Accents
    static let moss = Color(red: 0.494, green: 0.573, blue: 0.439)       // --c-moss
    static let mossDeep = Color(red: 0.353, green: 0.424, blue: 0.310) // --c-moss-deep
    static let mossSoft = Color(red: 0.659, green: 0.722, blue: 0.616) // --c-moss-soft
    static let olive = Color(red: 0.604, green: 0.588, blue: 0.439)    // --c-olive
    static let sage = Color(red: 0.698, green: 0.722, blue: 0.667)     // --c-sage

    // Sync state
    static let syncLocal = olive
    static let syncActive = Color(red: 0.580, green: 0.667, blue: 0.749) // --c-sync-active
    static let syncDone = moss
    static let syncFail = Color(red: 0.749, green: 0.478, blue: 0.369) // --c-sync-fail
    static let syncPaused = Color(red: 0.667, green: 0.580, blue: 0.420) // storage limit

    // Structural
    static let hairline = bone.opacity(0.08)
    static let hairlineStrong = bone.opacity(0.14)
    static let surfaceApp = graphite
    static let surfaceCard = charcoal
    static let surfaceElevated = bark
    static let surfaceOverlay = void.opacity(0.80)
}

enum NodeSpacing {
    static let sp0: CGFloat = 0
    static let sp1: CGFloat = 4
    static let sp2: CGFloat = 8
    static let sp3: CGFloat = 12
    static let sp4: CGFloat = 16
    static let sp5: CGFloat = 20
    static let sp6: CGFloat = 24
    static let sp8: CGFloat = 32
    static let sp10: CGFloat = 40
    static let sp12: CGFloat = 48
    static let sp16: CGFloat = 64
    static let sp20: CGFloat = 80
}

enum NodeRadius {
    static let xs: CGFloat = 2
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let pill: CGFloat = 999
}

enum NodeFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static let displayXL: CGFloat = 56
    static let display: CGFloat = 40
    static let title1: CGFloat = 28
    static let title2: CGFloat = 22
    static let title3: CGFloat = 17
    static let body: CGFloat = 15
    static let callout: CGFloat = 14
    static let caption: CGFloat = 12
    static let micro: CGFloat = 10
}

enum NodeMotion {
    static let durFast: Double = 0.12
    static let durBase: Double = 0.22
    static let durSlow: Double = 0.48

    static var quietAnimation: Animation {
        .timingCurve(0.32, 0.72, 0.24, 1, duration: durBase)
    }

    static var enterAnimation: Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: durBase)
    }
}

struct NodeShadow {
    static func photo() -> some ViewModifier {
        PhotoShadowModifier()
    }
}

private struct PhotoShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.8), radius: 30, x: 0, y: 18)
    }
}

extension View {
    func nodePhotoShadow() -> some View {
        modifier(PhotoShadowModifier())
    }
}
