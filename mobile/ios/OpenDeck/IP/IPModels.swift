import Foundation

// Ported from omni `OmniCore/Models/IP` + `Services/IP` — public-IP lookup
// via ipify → ipinfo.io (fallback ipapi.co), DNS via Cloudflare DoH.

struct IPInfo: Equatable, Sendable {
    let ip: String
    let version: String
    let city: String?
    let region: String?
    let countryName: String?
    let countryCode: String?
    let postal: String?
    let latitude: String?
    let longitude: String?
    let timezone: String?
    let org: String?
    let asn: String?
    let provider: String

    var coordinatesText: String? {
        guard let latitude, let longitude, !latitude.isEmpty, !longitude.isEmpty else { return nil }
        return "\(latitude), \(longitude)"
    }
}

struct DNSResponse: Codable, Equatable, Sendable {
    let status: Int
    let answers: [DNSAnswer]?

    private enum CodingKeys: String, CodingKey {
        case status = "Status"
        case answers = "Answer"
    }

    struct DNSAnswer: Codable, Equatable, Sendable {
        let name: String
        let type: Int
        let ttl: Int
        let data: String

        private enum CodingKeys: String, CodingKey {
            case name, type, data
            case ttl = "TTL"
        }
    }

    var answersText: String {
        guard let answers, !answers.isEmpty else { return "No A records found" }
        return answers.map(\.data).joined(separator: "\n")
    }
}

enum IPLookupError: Error, Equatable {
    case ipLookupFailed
    case dnsLookupFailed
    case invalidDomain
    case invalidResponse

    var message: String {
        switch self {
        case .ipLookupFailed: return "IP lookup failed"
        case .dnsLookupFailed: return "DNS lookup failed"
        case .invalidDomain: return "Enter a valid domain"
        case .invalidResponse: return "Unexpected server response"
        }
    }
}

struct IPLookupService {
    private let session: URLSession
    private let timeout: TimeInterval

    init(session: URLSession = .shared, timeout: TimeInterval = 10) {
        self.session = session
        self.timeout = timeout
    }

    func lookupIP() async throws -> IPInfo {
        let ip = try await fetchCurrentIP()
        if let info = try? await ipInfoLookup(ip: ip) {
            return info
        }
        return try await ipapiLookup(ip: ip)
    }

    func lookupDNS(domain: String) async throws -> DNSResponse {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: "https://cloudflare-dns.com/dns-query")
        else { throw IPLookupError.invalidDomain }
        components.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "type", value: "A"),
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = timeout
        request.setValue("application/dns-json", forHTTPHeaderField: "accept")

        let (data, response) = try await session.data(for: request)
        guard Self.isSuccess(response) else { throw IPLookupError.dnsLookupFailed }
        return try JSONDecoder().decode(DNSResponse.self, from: data)
    }

    private func fetchCurrentIP() async throws -> String {
        guard let url = URL(string: "https://api.ipify.org?format=json") else {
            throw IPLookupError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard Self.isSuccess(response), data.count < 256 else { throw IPLookupError.ipLookupFailed }
        struct IPify: Codable { let ip: String }
        let payload = try JSONDecoder().decode(IPify.self, from: data)
        guard !payload.ip.isEmpty else { throw IPLookupError.ipLookupFailed }
        return payload.ip
    }

    private func ipInfoLookup(ip: String) async throws -> IPInfo {
        guard let url = URL(string: "https://ipinfo.io/\(ip)/json") else {
            throw IPLookupError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard Self.isSuccess(response) else { throw IPLookupError.ipLookupFailed }
        return Self.parseIPInfo(try JSONDecoder().decode(IPInfoResponse.self, from: data))
    }

    private func ipapiLookup(ip: String) async throws -> IPInfo {
        guard let url = URL(string: "https://ipapi.co/\(ip)/json/") else {
            throw IPLookupError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard Self.isSuccess(response) else { throw IPLookupError.ipLookupFailed }
        return Self.parseIpapi(try JSONDecoder().decode(IpapiResponse.self, from: data))
    }

    private static func isSuccess(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else { return true }
        return (200 ... 299).contains(http.statusCode)
    }

    // MARK: - Parsing (port of omni IPInfoParsing)

    struct IPInfoResponse: Codable {
        let ip: String
        let city: String?
        let region: String?
        let country: String?
        let postal: String?
        let loc: String?
        let timezone: String?
        let org: String?
    }

    struct IpapiResponse: Codable {
        let ip: String
        let version: String?
        let city: String?
        let region: String?
        let country_name: String?
        let country_code: String?
        let postal: String?
        let latitude: Double?
        let longitude: Double?
        let timezone: String?
        let org: String?
        let asn: String?
    }

    static func parseIPInfo(_ r: IPInfoResponse) -> IPInfo {
        let coords = r.loc?.split(separator: ",").map(String.init)
        return IPInfo(
            ip: r.ip,
            version: r.ip.contains(":") ? "IPv6" : "IPv4",
            city: r.city, region: r.region,
            countryName: r.country, countryCode: r.country,
            postal: r.postal,
            latitude: coords?.first,
            longitude: coords?.dropFirst().first,
            timezone: r.timezone, org: r.org, asn: r.org,
            provider: "IPinfo"
        )
    }

    static func parseIpapi(_ r: IpapiResponse) -> IPInfo {
        IPInfo(
            ip: r.ip,
            version: r.version ?? (r.ip.contains(":") ? "IPv6" : "IPv4"),
            city: r.city, region: r.region,
            countryName: r.country_name, countryCode: r.country_code,
            postal: r.postal,
            latitude: r.latitude.map { String($0) },
            longitude: r.longitude.map { String($0) },
            timezone: r.timezone, org: r.org, asn: r.asn,
            provider: "ipapi"
        )
    }

    static func detectVPN(org: String?) -> Bool {
        guard let org else { return false }
        let lowercased = org.lowercased()
        return ["cloudflare", "amazon", "google", "digitalocean", "microsoft"]
            .contains { lowercased.contains($0) }
    }
}
