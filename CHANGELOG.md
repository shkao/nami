# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-07-23

### Added

- Auto-reconnect with exponential backoff (5 retries: 2s, 4s, 8s, 16s, 32s) on stream failure
- Network reachability monitoring via NWPathMonitor with automatic recovery
- Wake-from-sleep stream re-establishment
- Status line showing errors, reconnect state, and while playing the live indicator, stream type, and measured bitrate
- Sleep timer with 15/30/60 min presets or a custom stop time, persisted across launches
- Launch-at-login toggle via SMAppService, available from the Settings menu
- Station picker rows show frequency and location
- Custom app icon and menu bar template icon (flowing Hamonshu wave lines)
- Bundled Shippori Mincho typeface (subset) for the frequency display
- Drifting Hamonshu current behind the popover: flowing contour lines that drift while playing and settle when paused
- Stream health monitoring: `scripts/check_streams.sh` and a daily Stream Health GitHub Action that check every station's stream
- Tooltips on all controls
- VoiceOver accessibility labels on all controls
- Structured logging via os.Logger for stream lifecycle events
- Test gate in release workflow (tests must pass before build)
- Version injection from git tag into the binary

### Fixed

- Restore playback on the four smartstream HLS stations (Blue Shonan, Kamakura, Chofu, Salus), which began returning 403 without an `Origin: https://listenradio.jp` request header

### Changed

- Shonan Indigo visual redesign of the popover: muted misty-indigo palette, Shippori Mincho frequency display, sea-glass accent, Hamonshu wave motif, 242px width
- RadioPlayer and AppState now use @MainActor isolation (strict concurrency clean)
- KVO observers use Task { @MainActor } instead of DispatchQueue.main.async
- Signal quality updates skip no-op writes to avoid unnecessary SwiftUI diffs
- Release workflow injects MARKETING_VERSION and CURRENT_PROJECT_VERSION from tag

## [1.0.0] - 2024-01-25

### Added

- Initial release
- Menu bar app with waveform icon
- Stream 5 Japanese regional FM stations:
  - FM Blue Shonan (78.5 MHz) - Yokosuka
  - Shonan Beach FM (78.9 MHz) - Shonan
  - Kamakura FM (82.8 MHz) - Kamakura
  - Chofu FM (83.8 MHz) - Tokyo
  - FM Salus (84.1 MHz) - Yokohama
- Play/Pause control
- Volume slider with persistence
- Previous/Next station buttons
- Real-time signal quality indicator
- Station persistence (remembers last station)
- Compact popover UI (200px width)
