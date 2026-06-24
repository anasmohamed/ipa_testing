// NETWATCH — Models.swift
// Core data types for the threat-intelligence scanner.

import Foundation

// ── Risk Level ────────────────────────────────────────────
enum RiskLevel: String, CaseIterable, Codable, Comparable {
    case critical = "CRITICAL"
    case high     = "HIGH"
    case medium   = "MEDIUM"
    case clean    = "CLEAN"

    // For sorting: critical first
    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        let order: [RiskLevel] = [.critical, .high, .medium, .clean]
        return (order.firstIndex(of: lhs) ?? 99) < (order.firstIndex(of: rhs) ?? 99)
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.octagon.fill"
        case .high:     return "exclamationmark.triangle.fill"
        case .medium:   return "exclamationmark.circle.fill"
        case .clean:    return "checkmark.shield.fill"
        }
    }
}

// ── Suspicious Port ───────────────────────────────────────
struct SuspiciousPort: Identifiable, Codable, Hashable {
    var id: Int { port }
    let port:    Int
    let service: String
    let reason:  String
    let risk:    RiskLevel

    static let database: [Int: SuspiciousPort] = {
        let entries: [SuspiciousPort] = [
            // ── CRITICAL ──────────────────────────────────
            .init(port:23,    service:"TELNET",        reason:"Unencrypted remote shell — passwords in plaintext",              risk:.critical),
            .init(port:445,   service:"SMB",           reason:"EternalBlue/WannaCry ransomware vector — MS17-010",             risk:.critical),
            .init(port:3389,  service:"RDP",           reason:"Remote Desktop — BlueKeep CVE-2019-0708, brute-force target",   risk:.critical),
            .init(port:4444,  service:"METASPLOIT",    reason:"Default Metasploit reverse-shell listener port",                risk:.critical),
            .init(port:6667,  service:"IRC-BOTNET",    reason:"Classic IRC command-and-control channel for botnets",           risk:.critical),
            .init(port:31337, service:"BACK ORIFICE",  reason:"Classic Windows RAT backdoor — BO/BO2k malware",               risk:.critical),
            .init(port:12345, service:"NETBUS",        reason:"Historic Trojan/RAT granting remote desktop-level access",      risk:.critical),
            .init(port:1433,  service:"MS-SQL",        reason:"Database exposed — common ransomware lateral-movement pivot",   risk:.critical),
            .init(port:1234,  service:"BACKDOOR",      reason:"Generic malware default listener port",                        risk:.critical),
            // ── HIGH ──────────────────────────────────────
            .init(port:21,    service:"FTP",           reason:"Unencrypted file transfer — credentials sent in plaintext",     risk:.high),
            .init(port:25,    service:"SMTP",          reason:"Open relay abused for spam bots and phishing campaigns",        risk:.high),
            .init(port:135,   service:"MS-RPC",        reason:"Windows RPC mapper — historic worm propagation surface",        risk:.high),
            .init(port:3306,  service:"MYSQL",         reason:"Database directly reachable on network",                       risk:.high),
            .init(port:5432,  service:"POSTGRESQL",    reason:"Database publicly reachable without firewall",                  risk:.high),
            .init(port:5900,  service:"VNC",           reason:"Remote desktop — often unencrypted or weak auth",              risk:.high),
            .init(port:8080,  service:"HTTP-PROXY",    reason:"Open proxy relays malicious traffic and bypasses filters",      risk:.high),
            .init(port:9200,  service:"ELASTICSEARCH", reason:"Unauthenticated API exposes all indexed data",                  risk:.high),
            .init(port:27017, service:"MONGODB",       reason:"Source of massive data breaches — no auth by default",         risk:.high),
            .init(port:1080,  service:"SOCKS-PROXY",   reason:"Proxy tunnelling — malware exfiltration channel",              risk:.high),
            // ── MEDIUM ────────────────────────────────────
            .init(port:22,    service:"SSH",           reason:"Brute-force target when exposed to internet",                   risk:.medium),
            .init(port:111,   service:"RPCBIND",       reason:"NFS attack surface — enumerate available RPC services",         risk:.medium),
            .init(port:161,   service:"SNMP",          reason:"Network info disclosure with default community strings",        risk:.medium),
            .init(port:2049,  service:"NFS",           reason:"Network file share — data exfiltration if misconfigured",      risk:.medium),
            .init(port:6379,  service:"REDIS",         reason:"Unauthenticated Redis — popular cryptominer target",           risk:.medium),
            .init(port:9001,  service:"TOR/ORPORT",    reason:"Tor relay or hidden service activity",                         risk:.medium),
            .init(port:8443,  service:"HTTPS-ALT",     reason:"Alternate SSL — may host phishing or C2 panels",              risk:.medium),
            // ── LOW ───────────────────────────────────────
            .init(port:80,    service:"HTTP",          reason:"Unencrypted web — watch for unexpected services on LAN",       risk:.clean),
            .init(port:443,   service:"HTTPS",         reason:"Encrypted web — generally safe, verify service identity",      risk:.clean),
            .init(port:8888,  service:"HTTP-ALT",      reason:"Alternative HTTP — may be dev server or proxy tunnel",         risk:.clean),
        ]
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.port, $0) })
    }()

    static func lookup(_ port: Int) -> SuspiciousPort? { database[port] }
}

// ── Network Device ────────────────────────────────────────
struct NetworkDevice: Identifiable, Codable, Equatable {
    let id:              UUID
    var ipAddress:       String
    var hostname:        String?
    var openPorts:       [Int]
    var suspiciousPorts: [SuspiciousPort]
    var firstSeen:       Date
    var lastSeen:        Date
    var isCurrentDevice: Bool

    init(id: UUID = UUID(), ipAddress: String, hostname: String? = nil,
         openPorts: [Int] = [], suspiciousPorts: [SuspiciousPort] = [],
         firstSeen: Date = Date(), lastSeen: Date = Date(),
         isCurrentDevice: Bool = false) {
        self.id = id; self.ipAddress = ipAddress; self.hostname = hostname
        self.openPorts = openPorts; self.suspiciousPorts = suspiciousPorts
        self.firstSeen = firstSeen; self.lastSeen = lastSeen
        self.isCurrentDevice = isCurrentDevice
    }

    var highestRisk: RiskLevel {
        suspiciousPorts.map(\.risk).min() ?? .clean
    }

    var displayName: String { hostname ?? ipAddress }

    var lastOctet: Int {
        Int(ipAddress.split(separator: ".").last ?? "") ?? 0
    }

    /// Single-character tactical icon based on hostname heuristics
    var tacticalIcon: String {
        let h = (hostname ?? "").lowercased()
        if isCurrentDevice                              { return "i" }
        if h.contains("router") || h.contains("gate")  { return "R" }
        if h.contains("mac") || h.contains("apple")    { return "M" }
        if h.contains("win") || h.contains("pc")       { return "W" }
        if h.contains("ubuntu") || h.contains("linux") { return "U" }
        if h.contains("rasp") || h.contains("pi")      { return "π" }
        if h.contains("nas") || h.contains("storage")  { return "N" }
        if h.contains("game") || h.contains("steam")   { return "G" }
        if h.contains("tv") || h.contains("samsung")   { return "T" }
        if h.contains("print")                         { return "P" }
        return String(ipAddress.split(separator: ".").last?.prefix(1) ?? "?")
    }

    static func == (l: NetworkDevice, r: NetworkDevice) -> Bool { l.id == r.id }
}

// ── Scan Result ───────────────────────────────────────────
struct ScanResult: Identifiable, Codable {
    var id = UUID()
    let date:    Date
    var devices: [NetworkDevice]

    var threatCount: Int    { devices.filter { $0.highestRisk != .clean }.count }
    var criticalCount: Int  { devices.filter { $0.highestRisk == .critical }.count }
    var openPortCount: Int  { devices.flatMap(\.openPorts).count }
}
