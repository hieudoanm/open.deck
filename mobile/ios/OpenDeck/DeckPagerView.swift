import SwiftUI

/// Swipeable dashboard pages — the phone is meant to lie horizontally like a
/// Stream Deck, so every feature is a full-bleed page flipped with a
/// horizontal swipe (Android parity: `HorizontalPager` in `MainActivity`).
enum DeckPage: Int, Hashable, CaseIterable {
    case deck
    case clock
    case system
    case ip
    case ports
    case apps
    case clipboard
    case nfc

    var title: String {
        switch self {
        case .deck: return "Deck"
        case .clock: return "Clock"
        case .system: return "System"
        case .ip: return "IP"
        case .ports: return "Ports"
        case .apps: return "Apps"
        case .clipboard: return "Clipboard"
        case .nfc: return "NFC"
        }
    }

    var systemImage: String {
        switch self {
        case .deck: return "display"
        case .clock: return "clock"
        case .system: return "cpu"
        case .ip: return "network"
        case .ports: return "list.number"
        case .apps: return "square.grid.2x2"
        case .clipboard: return "doc.on.doc"
        case .nfc: return "antenna.radiowaves.left.and.right"
        }
    }
}

struct DeckPagerView: View {
    @ObservedObject var model: DeckModel

    var body: some View {
        TabView(selection: $model.page) {
            deckPage.tag(DeckPage.deck)
            ClockView().tag(DeckPage.clock)
            SystemView(model: model).tag(DeckPage.system)
            IPView().tag(DeckPage.ip)
            PortsView(model: model).tag(DeckPage.ports)
            AppsView(model: model).tag(DeckPage.apps)
            ClipboardView(model: model).tag(DeckPage.clipboard)
            NfcView(model: model).tag(DeckPage.nfc)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // The stream page's mouse drag would fight the pager's pan gesture;
        // disable paging there — the page dots below still switch pages.
        .scrollDisabled(model.page == .deck && model.connected)
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            PageDots(current: model.page) { model.page = $0 }
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var deckPage: some View {
        if model.connected {
            StreamView(model: model)
        } else {
            ConnectView(model: model)
        }
    }
}

/// Custom page indicator — tappable dots (the stock index view is not).
private struct PageDots: View {
    let current: DeckPage
    let select: (DeckPage) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DeckPage.allCases, id: \.self) { page in
                Button {
                    select(page)
                } label: {
                    Capsule()
                        .fill(page == current ? DeckTheme.accent : Color.white.opacity(0.3))
                        .frame(width: page == current ? 18 : 6, height: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(page.title)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.45), in: Capsule())
    }
}
