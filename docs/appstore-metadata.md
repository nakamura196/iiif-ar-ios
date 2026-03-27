# App Store メタデータ

App Store Connect でアプリを作成する際に入力する情報。

## 基本情報

| 項目 | 値 |
|------|-----|
| アプリ名 | IIIF AR |
| サブタイトル | IIIF画像をARで実寸表示 |
| Bundle ID | com.nakamura196.iifar |
| SKU | iifar |
| プライマリ言語 | 日本語 |
| カテゴリ(Primary) | 教育 |
| カテゴリ(Secondary) | レファレンス |
| コンテンツの権利 | 第三者のコンテンツを使用しない（IIIF画像は各機関が公開するオープンデータ） |
| 年齢制限 | 4+ |
| 価格 | 無料 |

## 説明文（日本語）

```
IIIF（International Image Interoperability Framework）に対応した画像をAR（拡張現実）で実寸表示するアプリです。絵図、絵巻、古地図、写真など、IIIF Image APIで公開されている画像をAR空間に配置し、メタデータに記録された実寸で表示します。

【主な機能】
・IIIF Image APIに対応した画像をAR空間に実寸大で配置
・カメラの距離に応じてタイル画像を段階的に読み込み、高解像度で表示
・画像コレクション管理ツール「Pocket」と連携し、自分のコレクションをAR表示
・所蔵、製作年、法量、帰属、ライセンスなどのメタデータを表示
・Google / Appleアカウントでログイン（ゲストモードでも利用可能）
・応援（Tip Jar）機能

【使い方】
1. ギャラリーからサンプル画像を選択、またはログインしてマイコレクションから選択
2. 画像の詳細情報とメタデータを確認
3.「ARで配置」をタップし、床面を検出
4. 画像が実寸大でAR空間に表示される

【対応するIIIF画像】
・IIIF Image API 2.0準拠のサーバーから配信される画像
・IIIF Presentation API 3.0のManifestに対応
・PhysicalDimensionsサービスによる実寸情報の自動取得

ソースコード: https://github.com/nakamura196/iiif-ar-ios
```

## 説明文（英語）

```
Display IIIF (International Image Interoperability Framework) images in augmented reality at their recorded physical dimensions. This app supports a wide range of materials published via IIIF Image API, including historical illustrations, picture scrolls, maps, and photographs.

Features:
• Place IIIF images in AR space at their actual physical size
• Progressive tile loading based on camera distance for high-resolution display
• Integration with "Pocket" collection management tool to view your own collections in AR
• Display metadata: institution, date, dimensions, attribution, license
• Sign in with Google or Apple (guest mode available without login)
• Tip Jar for voluntary support

How to Use:
1. Select a sample image from the gallery, or sign in and choose from your collections
2. Review image details and metadata
3. Tap "Place in AR" and detect a flat surface
4. The image appears in AR at its recorded physical size

Supported IIIF Images:
• Images served from IIIF Image API 2.0 compliant servers
• IIIF Presentation API 3.0 Manifests
• Automatic physical dimension extraction from PhysicalDimensions service

Source code: https://github.com/nakamura196/iiif-ar-ios
```

## キーワード（日本語、最大100文字）

```
IIIF,AR,拡張現実,絵図,絵巻,古地図,歴史,デジタルアーカイブ,博物館,図書館,実寸
```

## キーワード（英語）

```
IIIF,AR,augmented,reality,historical,illustration,scroll,museum,library,archive
```

## プロモーションテキスト（日本語、170文字以内）

```
図書館・博物館がIIIFで公開する画像をARで実寸表示。絵図、絵巻、古地図、写真などをAR空間に配置し、メタデータとともに閲覧できます。Pocket連携でマイコレクションのAR表示にも対応。
```

## プロモーションテキスト（英語）

```
View IIIF images from libraries and museums in AR at actual scale. Place illustrations, scrolls, maps, and photographs in augmented reality with full metadata display. Pocket integration for your own collections.
```

## サポートURL（ユーザーの問い合わせ先）

```
https://github.com/nakamura196/iiif-ar-ios/issues
```

## マーケティングURL（アプリ紹介ページ）

```
https://nakamura196.github.io/iiif-ar-ios/
```

## プライバシーポリシーURL

```
https://nakamura196.github.io/iiif-ar-ios/privacy.html
```

## App Store URL

```
https://apps.apple.com/app/iiif-ar/id6761031891
```

## スクリーンショット要件

| デバイス | サイズ | 必須 |
|---------|--------|------|
| iPhone 6.7" (15 Pro Max) | 1290 x 2796 | 必須 |
| iPad 12.9" (6th gen) | 2048 x 2732 | iPad対応なら必須 |

> **注意**: ARアプリのため、シミュレータではスクリーンショットの自動生成ができない。
> 実機でAR画面を表示した状態のスクリーンショットを撮影すること。

### スクリーンショット案（最低3枚）

1. **ログイン画面**: Google / Apple Sign-In とゲストモード
2. **ギャラリー**: サンプル画像一覧とマイコレクションタブ
3. **詳細画面**: メタデータ表示（所蔵、法量、帰属等）
4. **AR表示**: 画像がAR空間に実寸表示されている場面
5. **拡大表示**: AR空間で画像の細部に近づいて観察している場面

## App Review 向けメモ

```
This app displays IIIF-compatible images (illustrations, scrolls, maps, photographs) in AR at their recorded physical dimensions.

NEW IN 1.1.0:
- Optional sign-in with Google or Apple to access personal IIIF collections from "Pocket" (https://pocket.webcatplus.jp)
- Guest mode available — no login required to use sample images
- Metadata display (institution, date, dimensions, attribution, license)

TO TEST:
1. Launch the app and tap "Continue as Guest" to skip login
2. In the gallery, select a sample image (e.g., "海東諸国紀")
3. Tap "ARで配置" to place it in AR
4. Point the camera at a flat surface and tap to place
5. To test login: use Google or Apple Sign-In, then switch to "マイコレクション" tab

The app requires a device with ARKit support (A12 chip or later).
IIIF images are publicly available from libraries and museums worldwide.
Sign-in is optional and used only to access the user's own collections.
```
