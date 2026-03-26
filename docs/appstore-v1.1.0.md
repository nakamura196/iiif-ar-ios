# App Store 1.1.0 提出情報

## whatsNew（新機能）

### 日本語
```
- Googleアカウントでログインし、自分のIIIFコレクションをAR表示できるようになりました
- 画像コレクション管理ツール「Pocket」との連携
- メタデータ表示（所蔵、製作年、法量、帰属、ライセンス）
- 実寸情報（physicalScale）の表示に対応
- アプリの安定性とパフォーマンスを改善
```

### 英語
```
- Sign in with Google to view your own IIIF collections in AR
- Integration with "Pocket" image collection management tool
- Display metadata (institution, date, dimensions, attribution, license)
- Support for physical dimensions (physicalScale)
- Improved app stability and performance
```

## App Review 向けメモ（審査用）

```
This app displays IIIF-compatible historical maps and illustrations in AR at actual scale.

NEW IN 1.1.0:
- Users can optionally sign in with Google to access their own IIIF image collections from the "Pocket" web service (https://pocket.webcatplus.jp).
- Guest mode is available — no login required to use sample images.
- Added metadata display (institution, date, dimensions, attribution).

TO TEST:
1. Launch the app. You can tap "Continue as Guest" to skip login.
2. In the gallery, select a sample image (e.g., "海東諸国紀").
3. Tap "AR で配置" to enter AR mode.
4. Point the camera at a flat surface and tap to place the image.
5. To test the login feature: tap the Google Sign-In button on the login screen.
6. After login, switch to the "マイコレクション" tab to see cloud collections.

The app requires a device with ARKit support (A12 chip or later).
IIIF images are publicly available from libraries and museums worldwide.
The Google Sign-In is optional and used only to access the user's own collections.
```

## App Privacy（App Store Connect ブラウザで設定）

### 収集するデータの種類

| カテゴリ | データの種類 | 目的 | ユーザーに紐づく | トラッキング |
|---------|-----------|------|---------------|------------|
| 連絡先情報 | メールアドレス | アプリの機能 | はい | いいえ |
| ID | ユーザーID | アプリの機能 | はい | いいえ |
| 使用状況データ | 製品の操作 | 分析 | はい | いいえ |
| 診断 | クラッシュデータ | アプリの機能 | いいえ | いいえ |
| 診断 | パフォーマンスデータ | アプリの機能 | いいえ | いいえ |

### 設定手順
1. App Store Connect → アプリ → App Privacy
2. 「データ収集を開始」
3. 上記カテゴリごとに設定
4. 「トラッキングに使用しますか？」→ いいえ
5. 保存

## PrivacyInfo.xcprivacy

既存の PrivacyInfo.xcprivacy の確認が必要。Firebase SDKが使用するAPI（UserDefaults、disk space等）の宣言。

## バージョン情報

- MARKETING_VERSION: 1.1.0
- CURRENT_PROJECT_VERSION: 1
