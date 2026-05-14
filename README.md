# mac-menu-toolbar

Lightweight macOS menu bar app showing live system stats: CPU usage, memory usage, and network upload/download speed.

## Requirements

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Run

```bash
# Build
swift build -c release

# Package into .app
bash Bundle/make-app.sh

# Launch
open MacMenuToolbar.app
```

## What It Shows

```
[RAM] 42%  [CPU] 18%  ↑ 1.2M
                      ↓ 4.8M
```

- Memory and CPU usage as percentages
- Upload and download speed stacked vertically, auto-scaled (B / K / M / G)

## Auto-start on Login

1. Open **System Settings → General → Login Items**
2. Click `+` and add `MacMenuToolbar.app`
