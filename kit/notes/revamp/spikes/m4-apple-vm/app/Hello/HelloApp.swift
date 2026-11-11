import SwiftUI

@main
struct HelloApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Items found: \(count)")
                .font(.title)
                .accessibilityIdentifier("countLabel")
            Button("Count items") { count += 2 }
                .accessibilityIdentifier("findButton")
        }
        .padding(40)
    }
}
