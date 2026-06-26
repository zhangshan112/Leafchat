import SwiftUI

enum PaywallTab: String, CaseIterable, Identifiable {
    case subscription
    case consumables

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subscription: "LeafChat Plus"
        case .consumables: "AI Credits"
        }
    }
}

@MainActor
@Observable
final class PaywallPresenter {
    static let shared = PaywallPresenter()

    var isPresented = false
    var source: PaywallSource = .settings
    var initialTab: PaywallTab = .subscription

    private init() {}

    func present(source: PaywallSource, tab: PaywallTab = .subscription) {
        self.source = source
        self.initialTab = tab
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }
}

struct PaywallSheetModifier: ViewModifier {
    @Bindable private var presenter = PaywallPresenter.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $presenter.isPresented) {
                PaywallView(source: presenter.source, initialTab: presenter.initialTab)
            }
    }
}

extension View {
    func paywallSheet() -> some View {
        modifier(PaywallSheetModifier())
    }
}
