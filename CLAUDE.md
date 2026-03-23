# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IIIF AR (folder: IIFAR) — iOS AR app for placing IIIF historical maps and illustrations at real-world scale using ARKit. Users select a historical image from a gallery, then tap a detected floor plane to overlay it in augmented reality at its true physical dimensions. Includes a tile-based deep zoom system for close-up detail via IIIF Image API, a Tip Jar for voluntary support, camera permission handling, and Japanese/English localization.

- **Display name**: IIIF AR (set via `PRODUCT_NAME` in `project.yml`)
- **Bundle ID**: `com.nakamura196.iifar`
- **Deployment target**: iOS 16.0+
- **Language**: Swift 5.9, SwiftUI
- **Frameworks**: ARKit, RealityKit, StoreKit 2

## Build Commands

```bash
# Generate Xcode project (if project.yml changes)
xcodegen generate

# Debug build for device
xcodebuild build -project IIFAR.xcodeproj -scheme IIFAR -destination 'generic/platform=iOS'

# Build for simulator
xcodebuild build -project IIFAR.xcodeproj -scheme IIFAR -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

No linter configured. No tests configured.

## Architecture

### AR Pipeline (IIFAR/AR/)

1. **Plane Detection** — `ARWorldTrackingConfiguration` with `.horizontal` plane detection, mesh scene reconstruction, and person segmentation (when supported)
2. **Image Placement** — User taps a detected plane; `ARViewContainer.Coordinator` raycasts to the surface and places a `ModelEntity` plane mesh textured with the historical image
3. **Tile-Based Deep Zoom** — On each AR frame update, `TileManager` determines the camera distance, selects an appropriate IIIF zoom level, performs frustum culling, and overlays high-res tile textures on the placed image
4. **Corner Poles** — Optional yellow corner poles and top edges show the physical extent of the placed image

`ARViewContainer` is a `UIViewRepresentable` wrapping `ARView`. The `Coordinator` serves as `ARSessionDelegate` and manages all RealityKit entities. Callbacks from `ARManager` (opacity, pole height, debug settings) are forwarded to the Coordinator via closures.

### IIIF Tile System (IIFAR/Tile/)

The tile pipeline loads progressively higher-resolution tiles as the user moves closer:

1. **ZoomLevelMapper** — Maps camera-to-anchor distance to a IIIF scale factor (1..128). Includes 0.3s hysteresis to prevent flickering. Distance thresholds: >3m=128, >2m=64, >1.5m=32, >1m=16, >0.7m=8, >0.5m=4, >0.3m=2, <=0.3m=1
2. **TileGrid** — Computes IIIF tile regions, output sizes, and world-space rectangles for a given scale factor. Default tile size: 512px
3. **FrustumCuller** — Tests tile corners against the camera view-projection matrix to skip off-screen tiles. Uses 1.2x margin. Skips culling when total tile count <= 4
4. **TileFetcher** — Swift `actor` that fetches tile images via IIIF Image API with deduplication and max 4 concurrent requests
5. **TileTextureCache** — `NSCache`-backed store for `TextureResource` objects (limit: 200 entries)
6. **TileManager** — `@MainActor` orchestrator. On each AR frame (throttled to 0.2s), it: selects zoom level, rebuilds tile entity grid if scale changed, frustum-culls, applies cached textures, and enqueues fetches for missing tiles

IIIF tile URL format: `{baseURL}/{x},{y},{w},{h}/{outW},{outH}/0/default.jpg`

### UI Flow (IIFAR/Views/)

```text
ContentView (camera permission gate, then AR fullscreen + overlay controls)
  ├── CameraPermissionView — Requests camera access or directs to Settings
  ├── GalleryView (sheet) — List of SampleImage entries with thumbnails
  │   └── ImageDetailView — Image preview, metadata, "ARで配置" button
  ├── SettingsView (sheet) — Opacity slider, corner poles toggle, pole height,
  │   │                       plane detection visibility, image info, tile debug info
  │   └── TipJarView — StoreKit 2 consumable tip products (NavigationLink)
  └── AR overlay controls — Status messages, opacity slider, gallery/settings/trash buttons
```

- On launch, `CameraPermissionView` checks camera authorization before showing AR
- GalleryView is presented as a sheet
- Selecting an image and tapping "ARで配置" dismisses the gallery and loads the image via IIIF
- Status messages guide the user: plane scanning, tap to place, loading indicator
- After placement: opacity slider appears inline, trash button to remove

### Key Data Models

- **`SampleImage`** — Defines a historical map: `iiifBaseURL`, pixel dimensions, real-world dimensions in cm, computed `cmPerPixelX`/`cmPerPixelY`, `realWidthMeters`/`realHeightMeters`. Provides `iiifImageURL(maxDimension:)` and `iiifTileURL(region:size:)` URL builders
- **`ARManager`** — `@MainActor ObservableObject` holding AR state: current image/sample, placement status, opacity (0.1-1.0), pole height (0.3-3.0m), rotation, tile debug info (zoom level, visible/loaded tile counts, camera distance). Communicates with ARViewContainer via closures (`onImageUpdated`, `onOpacityChanged`, etc.)
- **`TileKey`** — Hashable identifier for a tile: `scaleFactor`, `tileX`, `tileY`
- **`TipJarManager`** — `@MainActor ObservableObject` managing StoreKit 2 product loading and consumable purchases

### IIIF Integration

- **IIIF Image API 2.0** via `IIIFService` (Swift `actor`, singleton)
- Thumbnail fetch: `{baseURL}/full/!400,400/0/default.jpg`
- AR overview fetch: `{baseURL}/full/!1024,1024/0/default.jpg`
- Tile fetch: `{baseURL}/{x},{y},{w},{h}/{outW},{outH}/0/default.jpg`
- Fallback: `DummyImageGenerator` creates a labeled placeholder with grid lines (10cm intervals), size badge coloring, and scale info when IIIF fetch fails

### Tip Jar (IIFAR/Store/)

StoreKit 2 consumable in-app purchases for voluntary support. Three tiers defined in `TipJar.storekit`:

| Product ID | Price | ja | en |
|---|---|---|---|
| `com.nakamura196.iifar.tip.small` | $0.99 | 小さな応援 | Small Tip |
| `com.nakamura196.iifar.tip.medium` | $2.99 | 応援 | Medium Tip |
| `com.nakamura196.iifar.tip.large` | $4.99 | 大きな応援 | Large Tip |

`TipJarManager` handles product loading, purchase flow, and verification. `TipJarView` is accessible from SettingsView via NavigationLink. The StoreKit configuration is linked in the scheme's run settings.

### Sample Images (hardcoded)

Three Ryukyu-related historical maps served via Cantaloupe IIIF server (`cantaloupe.lab.hi.u-tokyo.ac.jp`):

| ID | Name | Size Label | Pixels | Real Size |
|----|------|-----------|--------|-----------|
| `kaitou` | 海東諸国紀 | 小 | 4474x3918 | 32.6x21.2 cm |
| `sho` | 琉球国之図 | 大 | 25167x12483 | 96.8x47.3 cm |
| `ryukyu` | 琉球国図 | 特大 | 9449x20724 | 87.8x175.8 cm |

### Localization

Japanese (`ja.lproj/Localizable.strings`) and English (`en.lproj/Localizable.strings`). Covers settings labels, status messages, gallery/toolbar strings, size labels, and error messages. Default locale is Japanese.

## File Structure

```
IIFAR/
├── IIIFARApp.swift              # @main App entry point
├── Info.plist                   # Camera usage, ARKit capability, orientations
├── Assets.xcassets/             # App icon, accent color
├── PrivacyInfo.xcprivacy        # Privacy manifest (no tracking, no collected data)
├── TipJar.storekit              # StoreKit configuration (3 consumable tips)
├── ja.lproj/Localizable.strings # Japanese localization
├── en.lproj/Localizable.strings # English localization
├── Models/
│   ├── SampleImage.swift        # Image metadata + IIIF URL builders
│   ├── IIIFService.swift        # IIIF fetch actor
│   └── DummyImageGenerator.swift# Placeholder image with grid when IIIF fails
├── AR/
│   ├── ARManager.swift          # AR state (ObservableObject)
│   └── ARViewContainer.swift    # UIViewRepresentable + Coordinator (ARSessionDelegate)
├── Store/
│   └── TipJarManager.swift      # StoreKit 2 product loading + purchase
├── Tile/
│   ├── TileKey.swift            # Tile identifier
│   ├── TileGrid.swift           # IIIF region/size computation + world-space mapping
│   ├── ZoomLevelMapper.swift    # Distance-to-scale-factor with hysteresis
│   ├── FrustumCuller.swift      # View frustum visibility test
│   ├── TileFetcher.swift        # Concurrent tile download actor
│   ├── TileTextureCache.swift   # NSCache for TextureResource
│   └── TileManager.swift        # Orchestrates tile loading per AR frame
└── Views/
    ├── ContentView.swift        # Camera permission gate + AR view + overlay controls
    ├── CameraPermissionView.swift # Camera authorization request / settings redirect
    ├── GalleryView.swift        # Image list with thumbnails
    ├── ImageDetailView.swift    # Image detail + metadata
    ├── SettingsView.swift       # Display, debug, tile info, and tip jar link
    └── TipJarView.swift         # Tip Jar purchase UI
project.yml                      # XcodeGen project definition
```

## Project Generation

Uses **XcodeGen** (`project.yml`). After modifying project settings, run `xcodegen generate` to regenerate `IIFAR.xcodeproj`.
