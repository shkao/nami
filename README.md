# Nami (波)

A lightweight macOS menu bar app for streaming Japanese regional FM radio stations.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- Stream Japanese regional FM radio stations from the menu bar
- Real-time signal quality indicator
- Volume control with persistence
- Quick station switching with previous/next buttons
- Remembers your last station and volume settings
- Minimal resource usage (~30MB memory)

## Stations

| Station | Frequency | Location |
|---------|-----------|----------|
| FM Blue Shonan | 78.5 MHz | Yokosuka |
| Shonan Beach FM | 78.9 MHz | Shonan |
| Kamakura FM | 82.8 MHz | Kamakura |
| Chofu FM | 83.8 MHz | Tokyo |
| FM Salus | 84.1 MHz | Yokohama |

## Installation

### Option 1: Download Pre-built App (Recommended)

1. Go to [Releases](../../releases)
2. Download `Nami.zip` from the latest release
3. Extract the ZIP file
4. Drag `Nami.app` to your Applications folder
5. Open Nami from Applications

> **Note for unsigned builds**: On first launch, macOS may block the app. To open:
> - Right-click (or Control-click) on Nami.app
> - Select "Open" from the context menu
> - Click "Open" in the dialog that appears

### Option 2: Build from Source

#### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later

#### Steps

```bash
# Clone the repository
git clone https://github.com/yourusername/Nami.git
cd Nami

# Build the app
xcodebuild -scheme Nami -configuration Release build

# Find the built app
open ~/Library/Developer/Xcode/DerivedData/Nami-*/Build/Products/Release/
```

Or open `Nami.xcodeproj` in Xcode and press `Cmd+R` to build and run.

## Usage

1. Click the waveform icon in the menu bar
2. Click the play button to start streaming
3. Use the dropdown to select a station, or use ⏮/⏭ to switch
4. Adjust volume with the slider
5. Click "Quit" to exit

### Signal Quality Indicator

The bars next to the station name show connection quality:
- ▂▄▆ (3 green bars): Excellent connection
- ▂▄░ (2 green bars): Good connection
- ▂░░ (1 orange bar): Poor connection (may buffer)

## Configuration

Settings are automatically saved:
- **Volume**: Persisted between sessions
- **Last Station**: Automatically restored on launch

Settings are stored in UserDefaults (`com.nami.app`).

## Architecture

```
Nami/
├── App/
│   └── NamiApp.swift         # App entry point with MenuBarExtra
├── Audio/
│   └── RadioPlayer.swift     # AVPlayer wrapper, stream handling
├── Models/
│   ├── AppState.swift        # Observable app state
│   └── Station.swift         # Station definitions
├── Views/
│   └── ContentView.swift     # Main popover UI
└── Resources/
    ├── Assets.xcassets       # App icons
    └── Info.plist            # App configuration (LSUIElement=YES)
```

## Development

### Building

```bash
# Debug build
xcodebuild -scheme Nami -configuration Debug build

# Release build
xcodebuild -scheme Nami -configuration Release build

# Clean build
xcodebuild -scheme Nami clean build
```

### Creating a Release

Releases are automatically built by GitHub Actions when you push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This will:
1. Build the app in Release configuration
2. Create a ZIP archive
3. Create a GitHub Release with the artifact

## Troubleshooting

### App won't open (macOS security)

For unsigned builds, macOS Gatekeeper may block the app:

**Method 1: Right-click to open**
1. Right-click (or Control-click) on Nami.app
2. Select "Open" from the context menu
3. Click "Open" in the security dialog

**Method 2: System Settings**
1. Open System Settings → Privacy & Security
2. Scroll down to find "Nami was blocked"
3. Click "Open Anyway"

### No audio playing

1. Check your system volume is not muted
2. Check the in-app volume slider
3. Try switching to a different station
4. Verify your internet connection

### Stream keeps buffering

- Check your internet connection
- Try a different station (some may have better servers)
- The signal quality indicator shows real-time connection status

## Future Plans

- Real-time Japanese transcription using mlx-whisper
- Speech detection to skip music portions
- Scrolling transcript view

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -am 'Add my feature'`
4. Push to branch: `git push origin feature/my-feature`
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Stream sources provided by respective radio stations
- Built with SwiftUI and AVFoundation
