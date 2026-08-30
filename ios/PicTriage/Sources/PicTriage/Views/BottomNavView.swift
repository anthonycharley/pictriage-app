import SwiftUI

struct BottomNavView: View {
    @EnvironmentObject var state: AppState

    private struct NavItem {
        let key: String
        let label: String
        let systemImage: String
    }

    private let items: [NavItem] = [
        NavItem(key: "home", label: String(localized: "Home"), systemImage: "house.fill"),
        NavItem(key: "duplicates", label: String(localized: "Duplicates"), systemImage: "square.on.square"),
        NavItem(key: "screenshots", label: String(localized: "Shots"), systemImage: "viewfinder"),
        NavItem(key: "queue", label: String(localized: "Queue"), systemImage: "trash"),
        NavItem(key: "settings", label: String(localized: "Settings"), systemImage: "gearshape")
    ]

    private var activeKey: String {
        switch state.tab {
        case .home: return "home"
        case .review: return state.reviewKind == .duplicates ? "duplicates" : "screenshots"
        case .queue: return "queue"
        case .settings: return "settings"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.key) { item in
                navButton(item)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 72)
        .background(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Theme.navBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: Color(hex: "5A4123").opacity(0.16), radius: 30, x: 0, y: 12)
    }

    private func navButton(_ item: NavItem) -> some View {
        let active = activeKey == item.key
        return Button {
            switch item.key {
            case "duplicates": state.go(.review, reviewKind: .duplicates)
            case "screenshots": state.go(.review, reviewKind: .screenshots)
            case "queue": state.go(.queue)
            case "settings": state.go(.settings)
            default: state.go(.home)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(item.label)
                    .font(.heading(9.5))
            }
            .foregroundColor(active ? Theme.textPrimary : Theme.labelMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(active ? Theme.navActiveBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(alignment: .topTrailing) {
                if item.key == "queue", !state.queue.isEmpty {
                    Text("\(state.queue.count)")
                        .font(.heading(10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Theme.pink)
                        .clipShape(Capsule())
                        .offset(x: -12, y: 5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
