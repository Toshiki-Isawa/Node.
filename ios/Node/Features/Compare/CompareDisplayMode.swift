import Foundation

enum CompareDisplayMode: String, CaseIterable, Identifiable {
    case slider
    case split

    var id: String { rawValue }

    var analyticsValue: String { rawValue }
}

enum ComparePreferences {
    private static let displayModeKey = "compare.displayMode"

    static func loadDisplayMode() -> CompareDisplayMode {
        guard let raw = UserDefaults.standard.string(forKey: displayModeKey),
              let mode = CompareDisplayMode(rawValue: raw) else {
            return .slider
        }
        return mode
    }

    static func saveDisplayMode(_ mode: CompareDisplayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey)
    }
}
