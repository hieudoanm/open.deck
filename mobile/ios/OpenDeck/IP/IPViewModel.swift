import Foundation
import SwiftUI

@MainActor
final class IPViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(IPInfo)
        case offline
        case failed(String)
    }

    enum DNSState: Equatable {
        case idle
        case loading
        case loaded(DNSResponse)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var dnsState: DNSState = .idle
    @Published var domain = ""

    private let service = IPLookupService()

    var vpnDetected: Bool {
        guard case let .loaded(info) = state else { return false }
        return IPLookupService.detectVPN(org: info.org)
    }

    func refresh() async {
        state = .loading
        do {
            state = .loaded(try await service.lookupIP())
        } catch {
            state = Self.state(for: error)
        }
    }

    func lookupDNS() async {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        dnsState = .loading
        do {
            dnsState = .loaded(try await service.lookupDNS(domain: trimmed))
        } catch {
            dnsState = .failed("DNS lookup failed")
        }
    }

    private static func state(for error: Error) -> State {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost,
                 .networkConnectionLost, .timedOut, .dnsLookupFailed,
                 .internationalRoamingOff:
                return .offline
            default:
                return .failed(urlError.localizedDescription)
            }
        }
        if let e = error as? IPLookupError { return .failed(e.message) }
        return .failed(error.localizedDescription)
    }
}
