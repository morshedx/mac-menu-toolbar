import AppKit
import Combine
import ServiceManagement
import SwiftUI

@main
struct MacMenuToolbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hostingView: NSHostingView<MenuBarLabel>!
    private let stats = StatsViewModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self

            let view = NSHostingView(rootView: MenuBarLabel(stats: stats))
            view.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 6),
                view.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -6),
                view.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
            hostingView = view
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 260, height: 320)
        popover.contentViewController = NSHostingController(rootView: MenuView(stats: stats))

        Publishers.CombineLatest4(stats.$cpuUsage, stats.$memoryUsage, stats.$downloadSpeed, stats.$uploadSpeed)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in self?.adjustLength() }
            .store(in: &cancellables)

        adjustLength()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func adjustLength() {
        guard let view = hostingView else { return }
        statusItem.length = view.fittingSize.width + 12
    }
}

struct MenuBarLabel: View {
    @ObservedObject var stats: StatsViewModel

    var body: some View {
        HStack(spacing: 6) {
            VStack(spacing: 0) {
                Text("temp")
                    .frame(width: 34, alignment: .leading)
                HStack(spacing: 3) {
                    LucideIconView(name: "thermometer", size: 11)
                    Text(stats.cpuTemp.map { "\(Int($0))°" } ?? "--°")
                        .frame(width: 34, alignment: .leading)
                }
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))

            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    LucideIconView(name: "cpu", size: 11)
                    Text("\(Int(stats.cpuUsage))%")
                        .frame(width: 34, alignment: .leading)
                }
                HStack(spacing: 3) {
                    LucideIconView(name: "memory-stick", size: 11)
                    Text("\(Int(stats.memoryUsage))%")
                        .frame(width: 34, alignment: .leading)
                }
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))

            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    LucideIconView(name: "arrow-up", size: 11)
                    Text(formatRateCompact(stats.uploadSpeed))
                        .monospacedDigit()
                        .frame(width: 66, alignment: .leading)
                }
                HStack(spacing: 3) {
                    LucideIconView(name: "arrow-down", size: 11)
                    Text(formatRateCompact(stats.downloadSpeed))
                        .monospacedDigit()
                        .frame(width: 66, alignment: .leading)
                }
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
        }
        .foregroundColor(.primary)
        .fixedSize()
    }
}

struct MenuView: View {
    @ObservedObject var stats: StatsViewModel
    @State private var openAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("System Stats").font(.headline)
            Divider()
            statRow(icon: "cpu",          label: "CPU",      value: String(format: "%.0f%%", stats.cpuUsage))
            statRow(icon: "memory-stick", label: "Memory",   value: String(format: "%.0f%%", stats.memoryUsage))
            statRow(icon: "thermometer",  label: "CPU Temp", value: stats.cpuTemp.map { String(format: "%.1f °C", $0) } ?? "n/a")
            Divider()
            statRow(icon: "arrow-down", label: "Download", value: formatRate(stats.downloadSpeed))
            statRow(icon: "arrow-up",   label: "Upload",   value: formatRate(stats.uploadSpeed))
            Divider()
            Toggle("Open at Login", isOn: $openAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: openAtLogin) { newValue in
                    let service = SMAppService.mainApp
                    do {
                        if newValue {
                            if service.status != .enabled { try service.register() }
                        } else {
                            if service.status == .enabled { try service.unregister() }
                        }
                    } catch {
                        NSLog("MacMenuToolbar: Open-at-Login toggle failed: \(error.localizedDescription)")
                        openAtLogin = (service.status == .enabled)
                    }
                }
            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            LucideIconView(name: icon, size: 14).foregroundColor(.secondary)
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(.body, design: .monospaced))
        }
    }
}

struct LucideIconView: View {
    let name: String
    var size: CGFloat = 14

    var body: some View {
        if let img = LucideIcon.image(name, size: size) {
            Image(nsImage: img)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "questionmark.square").frame(width: size, height: size)
        }
    }
}

enum LucideIcon {
    private static func svgURL(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "svg")
            ?? Bundle.module.url(forResource: name, withExtension: "svg")
    }

    static func image(_ name: String, size: CGFloat) -> NSImage? {
        guard let url = svgURL(name), let src = NSImage(contentsOf: url) else { return nil }
        src.size = NSSize(width: size, height: size)
        let out = NSImage(size: NSSize(width: size, height: size))
        out.lockFocus()
        src.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        out.unlockFocus()
        out.isTemplate = true
        return out
    }
}

func formatRate(_ bytesPerSec: Double) -> String {
    let units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var v = bytesPerSec
    var i = 0
    while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
    return String(format: i == 0 ? "%.0f %@" : "%.1f %@", v, units[i])
}

func formatRateCompact(_ bytesPerSec: Double) -> String {
    let units = ["KB/s", "MB/s", "GB/s"]
    var v = bytesPerSec / 1024.0
    var i = 0
    while v >= 999.95, i < units.count - 1 { v /= 1024; i += 1 }
    return String(format: "%5.1f%@", v, units[i])
}
