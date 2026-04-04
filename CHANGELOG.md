# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Auto-reconnect with exponential backoff (5 retries: 2s, 4s, 8s, 16s, 32s) on stream failure
- Network reachability monitoring via NWPathMonitor with automatic recovery
- Wake-from-sleep stream re-establishment
- Error and reconnecting banner in the UI
- Launch-at-login toggle via SMAppService
- VoiceOver accessibility labels on all controls
- Structured logging via os.Logger for stream lifecycle events
- Test gate in release workflow (tests must pass before build)
- Version injection from git tag into the binary

### Changed

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
