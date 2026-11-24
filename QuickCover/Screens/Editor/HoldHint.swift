import Foundation

/// The hint of design.md §7.3.3 (4.8.4「按住看原圖」) comes once per phone: the first time a covered
/// picture is seen. Whether it has been seen is kept with the editor's other preferences.
enum HoldHint {
    static let key = "editor.holdHintSeen"

    static func isDue(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: key)
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }
}
