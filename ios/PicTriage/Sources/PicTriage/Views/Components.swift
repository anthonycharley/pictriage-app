import SwiftUI

/// The circular "‹" back button used at the top of Review, Detail, and Queue screens.
struct BackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\u{2039}")
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 36, height: 36)
                .background(Color(hex: "F4E8D4"))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Stand-in for the prototype's `repeating-linear-gradient` diagonal stripe placeholder
/// used wherever a real photo thumbnail will eventually go.
struct DiagonalStripes: View {
    var stripeWidth: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let span = geo.size.width + geo.size.height
            let count = max(2, Int(span / stripeWidth) + 4)
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(i.isMultiple(of: 2) ? Theme.stripeLight : Theme.stripeDark)
                        .frame(width: stripeWidth)
                }
            }
            .frame(width: span, height: span)
            .rotationEffect(.degrees(45))
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .background(Theme.stripeLight)
        .clipped()
    }
}

/// A thin 1px divider line matching the design's card separators.
struct HairlineDivider: View {
    var body: some View {
        Rectangle().fill(Theme.dividerLine).frame(height: 1)
    }
}
