# App Store メタデータ

App Store Connect でアプリを作成する際に入力する情報。

## 基本情報

| 項目 | 値 |
|------|-----|
| アプリ名 | IIIF AR |
| サブタイトル | 歴史的絵図をARで実寸体験 |
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
IIIF対応の歴史的絵図・古地図をAR（拡張現実）で実寸表示するアプリです。

【主な機能】
・IIIF Image APIに対応した画像をAR空間に実寸大で配置
・歴史的絵図や古地図を現実の空間に重ねて閲覧
・ピンチ操作やドラッグで拡大・移動が可能
・IIIF Manifestの読み込みに対応
・複数の画像タイルを高解像度で表示

【使い方】
1. IIIF画像のURLまたはManifest URLを入力
2. ARモードを起動し、平面を検出
3. 歴史的絵図が実寸大でAR空間に出現
4. 自由に歩き回りながら絵図の細部を観察

【特徴】
・IIIF（International Image Interoperability Framework）準拠
・世界中の図書館・博物館が公開するデジタル画像に対応
・ネットワーク経由でIIIF画像を取得し、AR空間にレンダリング
・個人データの収集なし

ソースコード: https://github.com/nakamura196/iiif-ar-ios
```

## 説明文（英語）

```
View IIIF-compatible historical maps and illustrations in augmented reality at actual scale.

Features:
• Display IIIF Image API images in AR space at real-world scale
• Overlay historical maps and illustrations onto your physical environment
• Pinch to zoom and drag to reposition
• Load images via IIIF Manifest URLs
• High-resolution display with multi-tile rendering

How to Use:
1. Enter a IIIF image URL or Manifest URL
2. Launch AR mode and detect a flat surface
3. The historical map appears at actual scale in AR
4. Walk around and examine fine details up close

Highlights:
• Fully compliant with IIIF (International Image Interoperability Framework)
• Access digital images from libraries and museums worldwide
• Images fetched over the network and rendered in AR
• No personal data collection

Source code: https://github.com/nakamura196/iiif-ar-ios
```

## キーワード（日本語、最大100文字）

```
IIIF,AR,拡張現実,絵図,古地図,歴史,デジタルアーカイブ,博物館,図書館,実寸
```

## キーワード（英語）

```
IIIF,AR,augmented,reality,map,historical,museum,library,archive,heritage
```

## プロモーションテキスト（日本語、170文字以内）

```
世界中の図書館・博物館が公開する歴史的絵図をARで実寸体験。IIIF対応画像を拡張現実空間に配置し、古地図や絵巻物の細部を現実の空間で自由に観察できます。
```

## プロモーションテキスト（英語）

```
Experience historical maps from libraries and museums worldwide in AR at actual scale. Place IIIF-compatible images in augmented reality and explore every detail.
```

## サポートURL（ユーザーの問い合わせ先）

```
https://github.com/nakamura196/iiif-ar-ios/issues
```

## マーケティングURL（アプリ紹介ページ）

```
TODO: ランディングページを作成後にURLを設定する
```

## プライバシーポリシーURL

App Store 提出時に公開URLが必要。GitHub Pages 等にホストする:
```
https://nakamura196.github.io/iiif-ar-ios/privacy.html
```

## スクリーンショット要件

| デバイス | サイズ | 必須 |
|---------|--------|------|
| iPhone 6.7" (15 Pro Max) | 1290 x 2796 | 必須 |
| iPad 12.9" (6th gen) | 2048 x 2732 | iPad対応なら必須 |

> **注意**: ARアプリのため、シミュレータではスクリーンショットの自動生成ができない。
> 実機でAR画面を表示した状態のスクリーンショットを撮影すること。

### スクリーンショット案（最低3枚）

1. **AR表示**: 歴史的絵図がAR空間に実寸表示されている場面
2. **一覧画面**: 利用可能なIIIF画像の一覧
3. **拡大表示**: AR空間で絵図の細部に近づいて観察している場面

## App Review 向けメモ

```
This app displays IIIF-compatible historical maps and illustrations in AR at actual scale.
No account or login is required.
To test: the app includes sample IIIF image URLs. Tap one to load the image, then enter AR mode.
Point the camera at a flat surface (floor or table) to detect a plane, and the image will appear in AR.
The app requires a device with ARKit support (A12 chip or later).
IIIF images are publicly available from libraries and museums worldwide.
```
