# IIIF AR

IIIF Image API対応の画像をARで実寸配置するiOSアプリ。
An iOS app that places IIIF Image API images in AR at real-world scale.

床面を検出し、歴史地図や絵巻物などの高精細画像を実物大でAR空間に配置できます。タイルベースのディープズームにより、近づくと細部まで鮮明に表示されます。
Detect a floor surface and place high-resolution historical maps and picture scrolls at their actual physical size in AR. Tile-based deep zoom reveals fine details as you move closer.

[BookSnake](https://apps.apple.com/us/app/booksnake/id6478938687) にインスパイアされたプロジェクトです。
Inspired by [BookSnake](https://apps.apple.com/us/app/booksnake/id6478938687).

[![App Store](https://img.shields.io/badge/App%20Store-Download-blue?logo=apple&logoColor=white)](#)

📖 **GitHub Pages:** https://nakamura196.github.io/iiif-ar-ios/

## 機能 / Features

- **実寸AR配置 / Real-scale AR placement** — IIIF画像を実物大でAR空間の床面に配置 / Place IIIF images on detected floor surfaces at their actual physical dimensions
- **タイルベースディープズーム / Tile-based deep zoom** — 近づくと高解像度タイルを自動読込、巨大画像も滑らかに表示 / Automatically loads high-resolution tiles as you approach; renders even gigapixel images smoothly
- **視錐台カリング / Frustum culling** — カメラに映るタイルのみを取得し、メモリとネットワーク帯域を節約 / Fetches only tiles visible in the camera frustum, saving memory and bandwidth
- **IIIF URL入力 / IIIF URL input** — Image APIベースURL、info.json、Presentation API 3.0マニフェストに対応 / Supports Image API base URLs, info.json, and Presentation API 3.0 manifests
- **物理サイズ自動検出 / Auto-detect physical dimensions** — マニフェストのPhysicalDimensionサービスから実寸を自動取得 / Automatically extracts real-world dimensions from the manifest's PhysicalDimension service
- **回転 / Rotation** — 0° / 90° / 180° / 270° のプリセット回転 / Preset rotation at 0°, 90°, 180°, 270°
- **透明度調整 / Opacity control** — スライダーで画像の透明度をリアルタイム変更 / Adjust image opacity in real-time with a slider
- **コーナーポール / Corner poles** — 画像の四隅に高さ調整可能なポールを表示 / Display height-adjustable poles at the four corners of the image
- **サンプルギャラリー / Sample gallery** — 東京大学史料編纂所の歴史資料3点を収録 / Includes 3 historical materials from the Historiographical Institute, The University of Tokyo
- **応援（Tip Jar） / Tip Jar** — StoreKit 2によるアプリ内課金 / In-app tips via StoreKit 2
- **多言語対応 / Multilingual** — 日本語 / English

## サンプル画像 / Sample Images

すべて東京大学史料編纂所所蔵の資料です。
All materials are held by the Historiographical Institute, The University of Tokyo.

| 画像 / Image | サイズ / Size | ピクセル / Pixels | 実寸 / Physical |
|---|---|---|---|
| 海東諸国紀（1512年善本） | 小 | 4,474 x 3,918 | 32.6 x 21.2 cm |
| 倭寇図巻（明代末期） | 中 | 90,916 x 6,615 | 5.2 x 0.3 m |
| 正保琉球国悪鬼納島絵図写（国宝・島津家文書） | 大 | 49,797 x 28,435 | 6.2 x 3.5 m |

## 要件 / Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9
- ARKit対応デバイス / ARKit-compatible device

## セットアップ / Setup

```bash
git clone https://github.com/nakamura196/iiif-ar-ios.git
cd iiif-ar-ios

# Generate Xcode project
xcodegen generate

open IIFAR.xcodeproj
```

## ビルド / Build

```bash
# Debug build
xcodebuild build \
  -project IIFAR.xcodeproj \
  -scheme IIFAR \
  -destination 'generic/platform=iOS'

# Archive for App Store
./scripts/archive.sh
```

## 技術スタック / Technology Stack

| 技術 / Technology | 用途 / Purpose |
|---|---|
| ARKit + RealityKit | AR空間での床面検出・画像配置 / Floor detection and image placement in AR |
| IIIF Image API 2.0 | タイルベースの高解像度画像取得 / Tile-based high-resolution image fetching |
| IIIF Presentation API 3.0 | マニフェスト解析・物理サイズ取得 / Manifest parsing and physical dimension extraction |
| SwiftUI | ギャラリー・設定画面のUI / Gallery and settings UI |
| Swift Concurrency | 非同期タイル取得・並列サムネイル読込 / Async tile fetching and parallel thumbnail loading |
| StoreKit 2 | アプリ内課金（Tip Jar） / In-app purchases (Tip Jar) |
| XcodeGen | プロジェクトファイル生成 / Project file generation |

## ライセンス / License

このプロジェクトは [MIT License](LICENSE) のもとで公開されています。
This project is released under the [MIT License](LICENSE).
