# rawctl 自動更新功能實作計劃

## 概述

實作 macOS 應用程式的自動更新功能，使用 **Sparkle 2** 框架。

## 架構

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   rawctl App    │────▶│  Appcast XML     │────▶│  DMG Download   │
│  (Sparkle 2)    │     │  (Cloudflare R2) │     │  (Cloudflare R2)│
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## 一、DMG 託管方案比較

| 方案 | 優點 | 缺點 | 成本 |
|------|------|------|------|
| **GitHub Releases** | 免費、簡單、CI 整合好 | 大陸訪問慢 | 免費 |
| **Cloudflare R2** | 全球 CDN、無出站費用 | 需設定 | $0.015/GB 存儲 |
| **AWS S3 + CloudFront** | 成熟穩定 | 出站費用高 | $0.09/GB 出站 |

**建議：GitHub Releases + Cloudflare R2 鏡像**

## 二、Sparkle 2 整合步驟

### Step 1: 添加 Sparkle 依賴

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
]
```

或使用 SPM 在 Xcode 中添加：
- File → Add Package Dependencies
- URL: `https://github.com/sparkle-project/Sparkle`

### Step 2: 生成 EdDSA 密鑰對

```bash
# 生成私鑰（妥善保管！）
./bin/generate_keys

# 輸出：
# Private key saved to ~/Library/Sparkle/EdDSA.pub
# Public key: xxxxx (添加到 Info.plist)
```

### Step 3: 配置 Info.plist

```xml
<key>SUFeedURL</key>
<string>https://releases.rawctl.app/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>YOUR_ED25519_PUBLIC_KEY</string>

<key>SUEnableAutomaticChecks</key>
<true/>
```

### Step 4: 實作更新檢查 UI

```swift
// UpdaterManager.swift
import Sparkle

@MainActor
final class UpdaterManager: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheck: Date?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
}
```

### Step 5: 添加到 SwiftUI

```swift
// SettingsView.swift
struct UpdateSettingsView: View {
    @StateObject private var updater = UpdaterManager()

    var body: some View {
        Form {
            Section("Updates") {
                Toggle("Check automatically", isOn: $updater.automaticallyChecksForUpdates)

                Button("Check for Updates...") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}

// MenuBarExtra or Commands
Commands {
    CommandGroup(after: .appInfo) {
        Button("Check for Updates...") {
            UpdaterManager.shared.checkForUpdates()
        }
    }
}
```

## 三、Appcast XML 格式

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>rawctl Updates</title>
    <link>https://rawctl.app</link>
    <description>rawctl release updates</description>
    <language>en</language>

    <item>
      <title>Version 1.1.0</title>
      <pubDate>Mon, 06 Jan 2026 12:00:00 +0000</pubDate>
      <sparkle:version>1.1.0</sparkle:version>
      <sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h2>What's New in 1.1.0</h2>
        <ul>
          <li>Added AI-powered image restoration</li>
          <li>Improved RAW processing performance</li>
          <li>Bug fixes and stability improvements</li>
        </ul>
      ]]></description>
      <enclosure
        url="https://releases.rawctl.app/rawctl-1.1.0.dmg"
        sparkle:edSignature="SIGNATURE_HERE"
        length="52428800"
        type="application/octet-stream"/>
    </item>

  </channel>
</rss>
```

## 四、CI/CD 自動發布流程

### GitHub Actions Workflow

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Import signing certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.APPLE_CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
        run: |
          echo $CERTIFICATE_BASE64 | base64 --decode > certificate.p12
          security create-keychain -p "" build.keychain
          security import certificate.p12 -k build.keychain -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain

      - name: Build and sign
        run: ./scripts/build-dmg.sh ${GITHUB_REF#refs/tags/v}
        env:
          NOTARIZATION_APPLE_ID: ${{ secrets.NOTARIZATION_APPLE_ID }}
          NOTARIZATION_PASSWORD: ${{ secrets.NOTARIZATION_PASSWORD }}

      - name: Sign DMG for Sparkle
        run: |
          ./bin/sign_update releases/rawctl-*.dmg > signature.txt

      - name: Update appcast.xml
        run: ./scripts/update-appcast.sh

      - name: Upload to Cloudflare R2
        run: |
          aws s3 cp releases/ s3://rawctl-releases/ --recursive \
            --endpoint-url ${{ secrets.R2_ENDPOINT }}
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_KEY }}

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: releases/*
          generate_release_notes: true
```

## 五、Landing Page 下載按鈕更新

```tsx
// Hero.tsx - 更新下載按鈕
const DOWNLOAD_URL = 'https://releases.rawctl.app/rawctl-latest.dmg'

<Button variant="solid" href={DOWNLOAD_URL}>
  <Download className="w-5 h-5" />
  Download for Mac
</Button>
```

## 六、實作順序

### Phase 1: 基礎設施 (1-2 天)
- [ ] 設定 Cloudflare R2 bucket
- [ ] 配置自定義域名 releases.rawctl.app
- [ ] 生成 EdDSA 密鑰對

### Phase 2: App 整合 (2-3 天)
- [ ] 添加 Sparkle SPM 依賴
- [ ] 實作 UpdaterManager
- [ ] 添加設定頁面 UI
- [ ] 添加選單項目

### Phase 3: CI/CD (1-2 天)
- [ ] 設定 Apple Developer 證書 secrets
- [ ] 創建 GitHub Actions workflow
- [ ] 測試自動發布流程

### Phase 4: 測試與上線 (1 天)
- [ ] 測試更新流程
- [ ] 發布第一個正式版本
- [ ] 更新 Landing Page 下載連結

## 七、安全考量

1. **EdDSA 簽名**: 確保更新包完整性
2. **HTTPS**: 所有下載連結必須使用 HTTPS
3. **私鑰保護**: EdDSA 私鑰只存在 CI 環境
4. **公證**: 所有發布都經過 Apple 公證

## 八、用戶體驗

- 啟動時靜默檢查更新
- 設定中可關閉自動檢查
- 更新可選擇「稍後提醒」
- 顯示更新日誌
- 下載進度顯示
