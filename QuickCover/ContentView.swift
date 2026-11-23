import SwiftUI

struct ContentView: View {
    @State private var tapCount = 0
    #if SELF_CHECK
    /// The hidden way into the self-check page: hold the title picture for two seconds.
    @State private var showSelfCheck = false
    #endif

    var body: some View {
        // String literals in Text/Button/Label are localization keys resolved
        // through Localizable.xcstrings automatically. Interpolate variables
        // inside the literal ("Tap count: \(tapCount)") instead of
        // concatenating strings, so the whole phrase stays translatable.
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                    #if SELF_CHECK
                    .onLongPressGesture(minimumDuration: 2) { showSelfCheck = true }
                    #endif

                Text("Airbuild is ready")
                    .font(.title.bold())

                Text("Tap count: \(tapCount)")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("tap-count")

                Button("Tap me") {
                    tapCount += 1
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("primary-action")
            }
            .padding()
            .navigationTitle("Starter")
            #if SELF_CHECK
            .sheet(isPresented: $showSelfCheck) { SelfCheckView() }
            #endif
        }
    }
}

#Preview {
    ContentView()
}
