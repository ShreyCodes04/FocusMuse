import SwiftUI

struct MainTabView: View {
    enum FooterTab {
        case home
        case records
        case todo
    }

    @State private var selectedTab: FooterTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        LandingView()
                    }
                case .records:
                    NavigationStack {
                        RecordsView()
                    }
                case .todo:
                    NavigationStack {
                        TodoView {
                            selectedTab = .home
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                footerButton(icon: "house.fill", title: "Home", tab: .home)
                footerButton(icon: "chart.pie.fill", title: "Records", tab: .records)
                footerButton(icon: "checkmark.circle.fill", title: "Todo", tab: .todo)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.black)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func footerButton(icon: String, title: String, tab: FooterTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(selectedTab == tab ? .red : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
