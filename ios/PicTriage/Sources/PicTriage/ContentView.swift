import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.hasOnboarded {
                mainApp
            } else {
                OnboardingView()
            }
        }
    }

    private var mainApp: some View {
        ZStack {
            Theme.screenBackground.ignoresSafeArea()

            Group {
                if state.isHome {
                    HomeView()
                } else if state.isDetail, let group = state.selectedGroup {
                    DetailGridView(group: group)
                } else if state.isReview {
                    ReviewListView()
                } else if state.isQueue {
                    QueueView()
                } else if state.isSettings {
                    SettingsView()
                }
            }

            BottomNavView()
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            if let toast = state.toast {
                ToastView(text: toast)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 108)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(4)
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.toast)
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: Binding(
            get: { state.previewPhoto != nil },
            set: { isPresented in if !isPresented { state.closePreview() } }
        )) {
            if let group = state.selectedGroup {
                PreviewOverlayView(group: group)
            }
        }
    }
}
