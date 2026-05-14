import Darwin
import Foundation

final class NetworkSampler {
    private var prevIn: UInt64 = 0
    private var prevOut: UInt64 = 0
    private var prevTime: Date = .init()
    private var primed = false

    private let skipPrefixes = [
        "lo", "utun", "gif", "stf",
        "awdl", "llw", "anpi",
        "bridge", "vmenet", "ap",
        "p2p", "XHC"
    ]

    func sample() -> (down: Double, up: Double) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return (0, 0) }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let name = String(cString: cur.pointee.ifa_name)
            let family = cur.pointee.ifa_addr?.pointee.sa_family ?? 0

            if family == UInt8(AF_LINK), !shouldSkip(name),
               let raw = cur.pointee.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self).pointee
                totalIn  &+= UInt64(data.ifi_ibytes)
                totalOut &+= UInt64(data.ifi_obytes)
            }
            ptr = cur.pointee.ifa_next
        }

        let now = Date()
        let dt = now.timeIntervalSince(prevTime)

        defer {
            prevIn = totalIn
            prevOut = totalOut
            prevTime = now
            primed = true
        }

        guard primed, dt > 0 else { return (0, 0) }
        let dIn  = totalIn  >= prevIn  ? totalIn  &- prevIn  : 0
        let dOut = totalOut >= prevOut ? totalOut &- prevOut : 0
        return (Double(dIn) / dt, Double(dOut) / dt)
    }

    private func shouldSkip(_ name: String) -> Bool {
        for p in skipPrefixes where name.hasPrefix(p) { return true }
        return false
    }
}
