# Changelog

All notable changes to IIIF AR are documented here.

## [Unreleased]

### Added
- Tatami floor feature: AR-placed images now display a tatami mat grid underneath at real-world scale (1 unit = 1.82m × 1.82m, Edoma size)
- Floor type picker in Settings ("床の種類"): toggle between no floor and tatami
- Tatami floor texture uses ambientCG Tatami001 (CC0)

### Changed
- Debug section in Settings is now hidden in Release builds (`#if DEBUG`)
- Tatami texture upgraded to 2K resolution (ambientCG Tatami001, CC0) with solid-color heri border

## [1.1.0]

### Added
- Account deletion feature (App Store guideline 5.1.1)
- Apple Sign-In support
- Firebase Authentication and Google Sign-In
- My Collections tab: browse Pocket collections via IIIF Collection API
- CollectionItemsView: browse items in a collection with thumbnails
- ImageDetailView: unified detail view with metadata display
- Launch screen with app icon on dark navy background

### Fixed
- Tip Jar error on iPad (guideline 2.1a)
- Camera permission button text (App Store review rejection)
- CollectionItemsView now uses PocketAPIClient singleton correctly

### Changed
- App icon and samples updated to Historiographical Institute images
- Sample image descriptions updated from source metadata
- App Store URLs updated
- GoogleService-Info.plist removed from version control

## [1.0.0] — Initial Release

### Added
- AR placement of IIIF historical maps and illustrations at real-world scale
- Tile-based deep zoom via IIIF Image API (progressive resolution as camera moves closer)
- Three sample images: 海東諸国紀、琉球国之図、琉球国図
- Opacity slider and image rotation controls
- Guest mode (no login required)
- Japanese/English localization
- Tip Jar (StoreKit 2 consumable in-app purchases)
- Privacy Policy page (`docs/privacy.html`)
