import SwiftUI

/// Small uppercase tracked label used for section eyebrows / metadata.
public struct MicroLabel: View {
    let text: String
    public init(_ t: String) { text = t }
    public var body: some View {
        Text(text.uppercased())
            .font(.dsMicro)
            .tracking(1.2)
            .foregroundStyle(DS.ink3)
    }
}
