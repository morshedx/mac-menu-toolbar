# Plan: Mac Menubar Stats App

## Stack
- SwiftUI executable via Swift Package Manager
- macOS 13+ (`MenuBarExtra` API)
- `NSApp.setActivationPolicy(.accessory)` at launch → no Dock icon

## Project layout
```
mac-menu-toolbar/
├── Package.swift
├── Bundle/                          ← optional .app bundle wrapper
│   ├── Info.plist                   ← LSUIElement=YES, CFBundleIdentifier, etc.
│   └── make-app.sh                  ← post-build script: copy binary into .app/Contents/MacOS
└── Sources/
    ├── CSMC/                        ← C target (struct alignment + IOKit calls)
    │   ├── include/CSMC.h
    │   └── csmc.c
    └── MacMenuToolbar/              ← Swift executable
        ├── App.swift                ← @main + MenuBarExtra + MenuView + AppDelegate
        ├── StatsViewModel.swift     ← @MainActor ObservableObject, 1s Timer
        ├── CPUSampler.swift         ← host_statistics(HOST_CPU_LOAD_INFO)
        ├── MemorySampler.swift      ← host_statistics64 + sysctl hw.memsize
        ├── NetworkSampler.swift     ← getifaddrs + AF_LINK if_data byte counters
        └── TemperatureSampler.swift ← wraps CSMC, key fallback + probe
```

## Data sources
| Stat     | API                                                       | Notes                                                                                                                                                                                                |
| -------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CPU %    | `host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO,…)` | System-wide aggregate `host_cpu_load_info_data_t`. Delta ticks: `(total-idle)/total` ≡ `(user+sys+nice)/total`                                                                                       |
| Mem %    | `host_statistics64(…, HOST_VM_INFO64,…)` + `sysctlbyname("hw.memsize")` | "Memory used" = `(active + wired + compressor_page_count) * page_size`; % = used/total. Matches Activity Monitor "Memory Used". Speculative excluded (reclaimable, not pressure).                  |
| Net B/s  | `getifaddrs` → `if_data.ifi_ibytes/ifi_obytes`            | `sa_family == AF_LINK`. Skip prefixes: `lo`, `utun`, `gif`, `stf`, `awdl`, `llw`, `anpi`, `bridge`, `vmenet`, `ap`, `XHC`. Delta over dt.                                                            |
| CPU temp | SMC via `IOConnectCallStructMethod(conn, 2, …)`           | `data8 = 9` (kSMCGetKeyInfo) then `data8 = 5` (kSMCReadKey). Apple Silicon keys: `Tp01,Tp05,Tp09,Tp0D,Tp0H,Tp0L,Tp0P,Tp0T,Tp0X,Tp0b,Tp0f` (probe at startup, keep working subset). Intel fallback: `TC0D,TC0E,TC0F,TC0P`. Decode `flt ` (IEEE-754 LE float32) / `sp78` (s8.8 → `int16/256`). Average valid readings in 10–130°C. |

## Why C target for SMC
`SMCKeyData_t` is 80 bytes with specific padding: `keyInfo` (`uint32 dataSize; uint32 dataType; uint8 dataAttributes`) is 9 bytes padded to 12; `data32` needs 4-byte alignment (3-byte pad after `data8`). Swift struct layout not guaranteed identical to C. C struct = correct wire format for `IOConnectCallStructMethod`. Swift bridges via one func: `csmc_read(const char*, double*) -> bool`. Same layout on Intel and Apple Silicon (kext interface unchanged).

## UI
- **Menubar label**: `↓1.2M ↑45K  23% 67%` (monospaced digit)
  - Compact format keeps width <~22 chars; fallback truncation if temp added and label overflows
- **Popover** (`.menuBarExtraStyle(.window)`): rows for CPU, Mem, Temp, ↓, ↑, Quit
- Auto-scale bytes: B/s → KB/s → MB/s → GB/s

## Sampling
- Single `Timer.scheduledTimer` 1s on main runloop
- Each sampler holds prev counters for delta math
- First tick returns 0 for net (no baseline yet)
- SMC read failure → keep last value (cached); never blocks UI (sync read, but `IOConnectCallStructMethod` returns immediately — no kext hangs observed in practice). Wrap in try/catch-style guard, return nil on `kIOReturnError`.

## Concurrency
- ViewModel marked `@MainActor`; all samplers called from main; `@Published` updates on main → no isolation warnings
- Timer block dispatches `Task { @MainActor in self.tick() }` so weak-self capture is safe across actor hop

## SwiftPM target
```swift
.target(name: "CSMC", publicHeadersPath: "include",
        linkerSettings: [.linkedFramework("IOKit")]),
.executableTarget(name: "MacMenuToolbar", dependencies: ["CSMC"])
```
SwiftUI / AppKit / Foundation auto-linked by `import`. IOKit must be explicit for C target.

## Build / run
```
# dev
swift run -c release

# distribution (.app bundle for Login Items, codesigning, notarization)
swift build -c release
./Bundle/make-app.sh   # wraps binary into MacMenuToolbar.app with Info.plist (LSUIElement=YES)
codesign --force --deep --sign - MacMenuToolbar.app    # ad-hoc; replace `-` with Developer ID for distribution
```
`swift build` ad-hoc signs binary automatically on Apple Silicon — runs from `.build/release/` directly. No entitlements needed for SMC user-session read.

## Risks / mitigations
- **SMC keys vary per Mac model** → probe full list at startup, keep working subset; range filter 10–130°C drops garbage
- **Menubar label overflow** → cap formatter output; drop temp from label if needed
- **Bridged interface double-count** → `bridge` prefix in skip list; physical en0/en1 still counted
- **App distribution** → bundle as `.app` with `LSUIElement=YES` for hide-from-Dock at launch, login-item registration, future code signing
- **First-net-sample** → return (0,0); next tick has valid delta
