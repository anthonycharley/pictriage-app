import SwiftUI

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.heading(15))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Theme.dark)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
