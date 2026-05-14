import CSMC
import Foundation

final class TemperatureSampler {
    private let appleSiliconKeys = [
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0L",
        "Tp0P", "Tp0T", "Tp0X", "Tp0b", "Tp0f", "Tp0j"
    ]
    private let intelKeys = ["TC0D", "TC0E", "TC0F", "TC0P"]
    private var resolvedKeys: [String]?
    private var lastValid: Double?

    init() {
        _ = csmc_open()
    }

    deinit {
        csmc_close()
    }

    func read() -> Double? {
        if resolvedKeys == nil {
            let asWorking = appleSiliconKeys.filter { probe($0) }
            if !asWorking.isEmpty {
                resolvedKeys = asWorking
            } else {
                let intelWorking = intelKeys.filter { probe($0) }
                resolvedKeys = intelWorking
            }
        }
        guard let keys = resolvedKeys, !keys.isEmpty else { return lastValid }

        var sum: Double = 0
        var count = 0
        for k in keys {
            var v: Double = 0
            if csmc_read(k, &v), v > 10, v < 130 {
                sum += v
                count += 1
            }
        }
        if count > 0 {
            let avg = sum / Double(count)
            lastValid = avg
            return avg
        }
        return lastValid
    }

    private func probe(_ key: String) -> Bool {
        var v: Double = 0
        return csmc_read(key, &v) && v > 10 && v < 130
    }
}
