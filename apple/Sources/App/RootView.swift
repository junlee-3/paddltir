import SwiftUI
import PaddltirCore

struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Paddltir").font(.largeTitle.bold())
            // prove PaddltirCore links:
            Text("Boat capacity: \(Boat.standard.capacity)").monospacedDigit()
        }
        .padding()
    }
}
