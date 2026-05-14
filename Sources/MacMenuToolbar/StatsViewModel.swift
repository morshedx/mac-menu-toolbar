import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var cpuTemp: Double?
    @Published var downloadSpeed: Double = 0
    @Published var uploadSpeed: Double = 0

    private var timer: Timer?
    private let cpuSampler = CPUSampler()
    private let netSampler = NetworkSampler()
    private let tempSampler = TemperatureSampler()

    init() {
        tick()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    deinit {
        timer?.invalidate()
    }

    private func tick() {
        cpuUsage = cpuSampler.sample()
        memoryUsage = MemorySampler.sample()
        cpuTemp = tempSampler.read()
        let (down, up) = netSampler.sample()
        downloadSpeed = down
        uploadSpeed = up
    }
}
