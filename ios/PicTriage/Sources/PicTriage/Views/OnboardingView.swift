import SwiftUI

/// First-launch screen asking what to call the person, so Home can greet
/// them by name instead of a hardcoded placeholder.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var name: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 17))
                .shadow(color: Theme.cardShadow.opacity(0.18), radius: 10, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("Welcome to PicTriage")
                    .font(.heading(28))
                    .foregroundColor(Theme.textPrimary)
                Text("What should we call you?")
                    .font(.heading(16, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }

            TextField(String(localized: "Your name"), text: $name)
                .focused($fieldFocused)
                .font(.heading(19))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(save)
                .padding(16)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Button(action: save) {
                Text("Continue")
                    .font(.heading(17))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)

            Button(action: skip) {
                Text("Skip for now")
                    .font(.heading(14, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.screenBackground.ignoresSafeArea())
        .onAppear { fieldFocused = true }
    }

    private func save() {
        state.completeOnboarding(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func skip() {
        state.completeOnboarding(name: "")
    }
}
