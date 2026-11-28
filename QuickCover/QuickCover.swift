import SwiftUI

#if os(macOS)
extension Notification.Name {
    static let quickCoverShowWhatsNew = Notification.Name("quickcover.showWhatsNew")
}
#endif

@main
struct QuickCover: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("whatsnew.menuItem") {
                    NotificationCenter.default.post(name: .quickCoverShowWhatsNew, object: nil)
                }
            }
        }
        #endif
    }
}
