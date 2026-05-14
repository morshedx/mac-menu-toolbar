import Darwin
import Foundation

final class CPUSampler {
    private var prevTotal: UInt64 = 0
    private var prevIdle: UInt64 = 0
    private var primed = false

    func sample() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = UInt64(info.cpu_ticks.0)
        let sys  = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let total = user &+ sys &+ idle &+ nice

        defer {
            prevTotal = total
            prevIdle  = idle
            primed    = true
        }

        guard primed else { return 0 }
        let dTotal = total &- prevTotal
        let dIdle  = idle  &- prevIdle
        guard dTotal > 0 else { return 0 }
        let usage = Double(dTotal &- dIdle) / Double(dTotal) * 100.0
        return max(0, min(100, usage))
    }
}
