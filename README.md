# mac-menu-toolbar

Lightweight macOS menu bar app showing live system stats with no background daemons, no telemetry.

## Install

Download the latest DMG from [Releases](https://github.com/morshedx/mac-menu-toolbar/releases), drag **MacMenuToolbar** to Applications, and launch.

> If Gatekeeper blocks it: right-click the app → Open

## What It Shows

```
temp  [CPU] 22%  ↑ 1.0K
🌡 77°  [RAM] 74%  ↓ 4.0K
```

| Column | Info |
|--------|------|
| Temp | CPU die temperature (°C), averaged across cores |
| CPU | CPU usage % |
| RAM | Memory usage % |
| ↑ / ↓ | Upload / download speed, auto-scaled (B / K / M / G) |

## Build from Source

**Requirements:** macOS 13+, Xcode Command Line Tools

```bash
xcode-select --install   # if not already installed

git clone https://github.com/morshedx/mac-menu-toolbar
cd mac-menu-toolbar

swift build -c release
bash Bundle/make-app.sh
open MacMenuToolbar.app
```

## Release

```bash
bash Bundle/make-release.sh 1.0.0
```

Builds, packages a DMG, and publishes a GitHub Release.

## Auto-start on Login

**System Settings → General → Login Items → +** → add `MacMenuToolbar.app`
