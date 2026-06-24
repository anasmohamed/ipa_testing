// NETWATCH — NWScanner.swift
// Real LAN scanner using Apple's Network framework (App Store compliant).
// Phase 1: TCP connect-probe each host in the /24 subnet to detect live hosts.
// Phase 2: Port-probe each live host against the suspicious-port database.

import Foundation
import Network
import Darwin

@MainActor
final class NWScanner: ObservableObject {

    // ── Published state ───────────────────────────────────
    @Published var isScanning      = false
    @Published var progress: Double = 0          // 0.0 → 1.0
    @Published var phase: ScanPhase = .idle
    @Published var devices: [NetworkDevice] = []
    @Published var lastResult: ScanResult?
    @Published var errorMessage: String?
    @Published var currentIP: String = ""        // IP currently being probed

    enum ScanPhase: String {
        case idle      = "STANDBY"
        case discovery = "PHASE 1 · HOST DISCOVERY"
        case ports     = "PHASE 2 · PORT PROBE"
        case done      = "SCAN COMPLETE"
        case aborted   = "ABORTED"
    }

    // ── Tuning ────────────────────────────────────────────
    private let portTimeout: TimeInterval = 0.75
    private let maxConcurrent = 20
    private let probePorts = Array(SuspiciousPort.database.keys).sorted()

    private var task: Task<Void, Never>?

    // ── Public API ────────────────────────────────────────
    func startScan() {
        guard !isScanning else { return }
        task?.cancel()
        task = Task { await runScan() }
    }

    func stopScan() {
        task?.cancel()
        isScanning = false
        phase = .aborted
        progress = 0
        currentIP = ""
    }

    // ── Helpers exposed to views ──────────────────────────
    func localIPAddress() -> String? {
        var addr: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let iface = ptr {
            defer { ptr = iface.pointee.ifa_next }
            guard Int32(iface.pointee.ifa_addr.pointee.sa_family) == AF_INET,
                  String(cString: iface.pointee.ifa_name) == "en0" else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(iface.pointee.ifa_addr,
                        socklen_t(iface.pointee.ifa_addr.pointee.sa_len),
                        &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            addr = String(cString: host)
        }
        return addr
    }

    private func subnet() -> String? {
        guard let ip = localIPAddress() else { return nil }
        let p = ip.split(separator: ".")
        guard p.count == 4 else { return nil }
        return "\(p[0]).\(p[1]).\(p[2])"
    }

    // ── Core scan ─────────────────────────────────────────
    private func runScan() async {
        isScanning   = true
        progress     = 0
        devices      = []
        errorMessage = nil
        currentIP    = ""

        guard let sub = subnet() else {
            errorMessage = "Could not detect Wi-Fi subnet. Please connect to Wi-Fi."
            isScanning = false; phase = .idle
            return
        }

        let selfIP = localIPAddress() ?? ""
        let hosts  = (1...254).map { "\(sub).\($0)" }
        let total  = Double(hosts.count)

        // ── Phase 1: Host Discovery ───────────────────────
        phase = .discovery
        var live: [String] = []
        var done = 0.0

        await withTaskGroup(of: (String, Bool).self) { group in
            var inFlight = 0
            for host in hosts {
                while inFlight >= maxConcurrent {
                    if let (h, alive) = await group.next() {
                        inFlight -= 1; done += 1
                        progress = min(done / total * 0.45, 0.45)
                        currentIP = h
                        if alive { live.append(h) }
                    }
                }
                if Task.isCancelled { break }
                group.addTask { [weak self] in
                    guard let self else { return (host, false) }
                    let alive = await self.tcpProbe(host: host, port: 80, timeout: self.portTimeout)
                    return (host, alive)
                }
                inFlight += 1
            }
            for await (h, alive) in group {
                done += 1; progress = min(done / total * 0.45, 0.45)
                currentIP = h
                if alive { live.append(h) }
            }
        }

        if Task.isCancelled { isScanning = false; phase = .aborted; return }

        // ── Phase 2: Port probe ───────────────────────────
        phase = .ports
        let portTotal = Double(live.count * probePorts.count)
        var portDone  = 0.0

        for host in live {
            if Task.isCancelled { break }
            currentIP = host
            var openPorts: [Int] = []

            await withTaskGroup(of: (Int, Bool).self) { group in
                var inFlight2 = 0
                for port in probePorts {
                    while inFlight2 >= maxConcurrent {
                        if let (p, open) = await group.next() {
                            inFlight2 -= 1; portDone += 1
                            progress = 0.45 + min(portDone / portTotal * 0.55, 0.55)
                            if open { openPorts.append(p) }
                        }
                    }
                    if Task.isCancelled { break }
                    group.addTask { [weak self] in
                        guard let self else { return (port, false) }
                        let open = await self.tcpProbe(host: host, port: port, timeout: self.portTimeout)
                        return (port, open)
                    }
                    inFlight2 += 1
                }
                for await (p, open) in group {
                    portDone += 1
                    progress = 0.45 + min(portDone / portTotal * 0.55, 0.55)
                    if open { openPorts.append(p) }
                }
            }

            var device = NetworkDevice(
                ipAddress: host,
                openPorts: openPorts.sorted(),
                suspiciousPorts: openPorts.compactMap { SuspiciousPort.lookup($0) },
                isCurrentDevice: host == selfIP
            )
            device.hostname = await reverseDNS(for: host)
            device.lastSeen = Date()

            devices.append(device)

            // Fire alert for dangerous devices
            if device.highestRisk <= .high {
                NWNotifications.shared.alert(for: device)
            }
        }

        progress = 1.0
        isScanning = false
        currentIP  = ""

        if Task.isCancelled {
            phase = .aborted
        } else {
            phase = .done
            let result = ScanResult(date: Date(), devices: devices)
            lastResult = result
            NWScanHistory.shared.save(result)
            NWNotifications.shared.scanComplete(result: result)
        }
    }

    // ── TCP connect probe ─────────────────────────────────
    // Returns true if host:port is reachable (connected or refused — both
    // confirm the host is live). A timeout means filtered or down.
    private func tcpProbe(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { cont in
            let conn = NWConnection(
                host: .init(host),
                port: .init(integerLiteral: UInt16(port)),
                using: .tcp
            )
            var resumed = false
            let finish: (Bool) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                conn.cancel()
                cont.resume(returning: result)
            }
            let timer = DispatchWorkItem { finish(false) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timer.cancel(); finish(true)
                case .failed(let e):
                    let refused = (e as? POSIXError)?.code == .ECONNREFUSED
                    timer.cancel(); finish(refused)
                case .cancelled:
                    timer.cancel(); finish(false)
                default: break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
        }
    }

    // ── Reverse DNS ───────────────────────────────────────
    private func reverseDNS(for ip: String) async -> String? {
        await withCheckedContinuation { cont in
            var hints = addrinfo(); hints.ai_flags = AI_NUMERICHOST
            var res: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(ip, nil, &hints, &res) == 0 else { cont.resume(returning: nil); return }
            defer { freeaddrinfo(res) }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if let sa = res?.pointee.ai_addr {
                getnameinfo(sa, socklen_t(res!.pointee.ai_addrlen),
                            &host, socklen_t(host.count), nil, 0, NI_NAMEREQD)
            }
            let name = String(cString: host)
            cont.resume(returning: name.isEmpty ? nil : name)
        }
    }
}
