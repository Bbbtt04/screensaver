# Sparkle 2.x + GitHub Releases Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 集成 Sparkle 2.x，使 Agent永动机 客户端能通过 GitHub Releases 托管的 appcast.xml 自动检查并安装更新。

**Architecture:** 在 `AgentPrivacyLockClient` 中嵌入 `SPUStandardUpdaterController`，菜单栏菜单项触发手动检查；Sparkle 后台定时轮询。`appcast.xml` 提交到 GitHub 仓库 main 分支，DMG 作为 GitHub Release 资产上传。发布脚本 `scripts/release.sh` 负责构建、签名 appcast 条目、更新 XML、打 tag 并创建 Release。

**Tech Stack:** Sparkle 2.x (SPM binary xcframework), Swift 6, AppKit, GitHub Releases, `gh` CLI, EdDSA (Ed25519)

---

## File Map

| 文件 | 变更类型 | 职责 |
|------|---------|------|
| `Package.swift` | 修改 | 添加 Sparkle SPM 依赖 |
| `Sources/AgentPrivacyLockClient/main.swift` | 修改 | 集成 SPUUpdaterController，添加菜单项 |
| `scripts/package-internal.sh` | 修改 | 接受 env var 版本号；嵌入 Sparkle.framework + XPC services；Info.plist 添加 Sparkle 配置键 |
| `scripts/release.sh` | 新建 | 完整发布流水线：build → sign appcast → update XML → tag → gh release |
| `scripts/sparkle-bin/` | 新建（gitignore） | Sparkle CLI 工具（generate_keys / sign_update / generate_appcast） |
| `appcast.xml` | 新建 | Sparkle RSS feed，每次发布时由 release.sh 更新 |
| `.gitignore` | 修改 | 忽略 `scripts/sparkle-bin/`，忽略 `dist/` |

---

## Task 1: 下载 Sparkle CLI 工具

**Files:**
- Create: `scripts/sparkle-bin/` (gitignored directory)
- Modify: `.gitignore`

- [ ] **Step 1: 下载 Sparkle 2 最新发布包**

```bash
cd /Users/bint/Documents/screensaver

SPARKLE_VERSION="2.7.5"
curl -L "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
  -o /tmp/sparkle.tar.xz

mkdir -p scripts/sparkle-bin
tar -xJf /tmp/sparkle.tar.xz -C scripts/sparkle-bin --strip-components=0
rm /tmp/sparkle.tar.xz
```

- [ ] **Step 2: 验证工具存在**

```bash
ls scripts/sparkle-bin/bin/
# 应看到：generate_keys  sign_update  generate_appcast  ...
scripts/sparkle-bin/bin/generate_keys --help
```

Expected: 输出 generate_keys 用法说明，无报错。

- [ ] **Step 3: 添加到 .gitignore**

读取当前 `.gitignore`（若不存在则新建），追加：

```
scripts/sparkle-bin/
dist/
.build/
```

> 注意：`dist/` 已有构建产物，整体忽略较合理；若需要保留 `dist/` 中某些文件，按需调整。

- [ ] **Step 4: 提交**

```bash
git add .gitignore
git commit -m "chore: add sparkle-bin and dist to gitignore"
```

---

## Task 2: 生成 EdDSA 密钥对

**Files:** 仅影响 Keychain（私钥）和 `Package.swift`（下一任务用到公钥）。密钥不进版本库。

- [ ] **Step 1: 生成密钥**

```bash
scripts/sparkle-bin/bin/generate_keys
```

输出示例：
```
Public Key (ed25519):
  mP2p8XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=

A new signing key has been generated and saved to your Keychain.
Don't lose your private key or you won't be able to sign future updates.
```

- [ ] **Step 2: 记录公钥**

**将上方输出的 Base64 公钥（`mP2p8...=` 格式）保存到安全位置。** 后续 Task 3 会把它写入 `package-internal.sh` 的 `SPARKLE_PUBLIC_KEY` 变量。

> ⚠️ 私钥保存在 macOS Keychain，不在磁盘文件中。此 Mac 就是唯一的发布机器。如需迁移，参考 Sparkle 文档导出私钥。

---

## Task 3: 修改 package-internal.sh

接受 env var 版本号；写入 Sparkle 相关 Info.plist 键；嵌入 Sparkle.xcframework 和 XPC services；修复 rpath。

**Files:**
- Modify: `scripts/package-internal.sh`

- [ ] **Step 1: 在脚本顶部添加可配置变量**

将 `package-internal.sh` 开头的以下硬编码行：
```bash
VERSION="0.1.0"
BUILD_NUMBER="1"
```

改为（使用 env var 覆盖，保持向后兼容）：
```bash
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

# === GitHub Release 配置 ===
# 填入你的 GitHub owner 和 repo name
GITHUB_OWNER="${GITHUB_OWNER:-YOUR_GITHUB_OWNER}"
GITHUB_REPO="${GITHUB_REPO:-YOUR_GITHUB_REPO}"

# Sparkle EdDSA 公钥（由 generate_keys 生成）
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-REPLACE_WITH_YOUR_ED25519_PUBLIC_KEY}"
```

- [ ] **Step 2: 更新 Info.plist 模板，添加 Sparkle 和菜单栏键**

将 `cat > "$APP_PATH/Contents/Info.plist"` 的 heredoc 内容替换为：

```bash
cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSUIElement</key>
  <true/>
  <key>SUFeedURL</key>
  <string>https://raw.githubusercontent.com/$GITHUB_OWNER/$GITHUB_REPO/main/appcast.xml</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_KEY</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUCheckInterval</key>
  <integer>86400</integer>
</dict>
</plist>
EOF
```

- [ ] **Step 3: 在打包脚本中添加 Sparkle 框架嵌入步骤**

在 `echo "==> Ad-hoc signing app bundle"` 这行**之前**，插入：

```bash
echo "==> Embedding Sparkle framework"
swift package resolve 2>/dev/null || true

# SPM binary xcframework artifacts 路径
SPARKLE_XCFW="$ROOT_DIR/.build/artifacts/sparkle-project/Sparkle/Sparkle.xcframework"

if [[ ! -d "$SPARKLE_XCFW" ]]; then
  echo "ERROR: Sparkle.xcframework not found at $SPARKLE_XCFW" >&2
  echo "Run: swift package resolve" >&2
  exit 1
fi

# 选择 arm64 + x86_64 universal slice
SPARKLE_FW_SRC="$SPARKLE_XCFW/macos-arm64_x86_64/Sparkle.framework"

if [[ ! -d "$SPARKLE_FW_SRC" ]]; then
  echo "ERROR: Sparkle.framework not found at $SPARKLE_FW_SRC" >&2
  exit 1
fi

# 1. 复制 Sparkle.framework 到 Contents/Frameworks/
mkdir -p "$APP_PATH/Contents/Frameworks"
cp -R "$SPARKLE_FW_SRC" "$APP_PATH/Contents/Frameworks/Sparkle.framework"

# 2. 复制 XPC services 到 Contents/XPCServices/
XPC_SRC="$SPARKLE_FW_SRC/Versions/B/XPCServices"
if [[ -d "$XPC_SRC" ]]; then
  mkdir -p "$APP_PATH/Contents/XPCServices"
  cp -R "$XPC_SRC/." "$APP_PATH/Contents/XPCServices/"
  echo "    Copied XPC services: $(ls "$APP_PATH/Contents/XPCServices/")"
else
  echo "    Warning: XPC services dir not found at $XPC_SRC — Sparkle installer may not work"
fi

# 3. 修复 rpath，使二进制能找到 @executable_path/../Frameworks/Sparkle.framework
install_name_tool \
  -add_rpath "@executable_path/../Frameworks" \
  "$APP_PATH/Contents/MacOS/$APP_NAME" 2>/dev/null || true
```

- [ ] **Step 4: 验证脚本语法**

```bash
bash -n scripts/package-internal.sh
```

Expected: 无输出（语法无误）。

- [ ] **Step 5: 填写你的实际 GitHub 信息**

在脚本顶部，将占位符替换为真实值：
```bash
GITHUB_OWNER="your-actual-github-username"
GITHUB_REPO="your-actual-repo-name"
SPARKLE_PUBLIC_KEY="刚才 generate_keys 输出的公钥字符串"
```

- [ ] **Step 6: 提交**

```bash
git add scripts/package-internal.sh
git commit -m "feat: update packaging script for Sparkle + env var version"
```

---

## Task 4: 添加 Sparkle 到 Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: 添加 Sparkle 依赖**

将 `Package.swift` 的 `dependencies: []` 改为：

```swift
dependencies: [
    .package(
        url: "https://github.com/sparkle-project/Sparkle",
        from: "2.6.0"
    )
],
```

将 `AgentPrivacyLockClient` target 的 `dependencies` 改为：

```swift
.executableTarget(
    name: "AgentPrivacyLockClient",
    dependencies: [
        "AgentPrivacyLockCore",
        .product(name: "Sparkle", package: "Sparkle")
    ]
),
```

- [ ] **Step 2: 解析并验证下载**

```bash
swift package resolve
```

Expected: 下载 `Sparkle.xcframework` (约 40 MB)，`.build/artifacts/sparkle-project/Sparkle/Sparkle.xcframework` 目录存在。

```bash
ls .build/artifacts/sparkle-project/Sparkle/Sparkle.xcframework/
# 应看到：macos-arm64_x86_64/  Info.plist 等
```

- [ ] **Step 3: 编译验证（先不管 Sparkle 集成代码）**

```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!`（此时 Sparkle 已链接但代码中尚未使用，编译仍通过）

- [ ] **Step 4: 提交**

```bash
git add Package.swift Package.resolved
git commit -m "feat: add Sparkle 2.x SPM dependency"
```

---

## Task 5: 在 ClientAppDelegate 中集成 SPUUpdater

**Files:**
- Modify: `Sources/AgentPrivacyLockClient/main.swift`

Sparkle 的 `SPUStandardUpdaterController` 是最简集成方式：一行初始化，自动处理检查频率、UI 对话框、安装流程。菜单栏添加"检查更新"菜单项触发手动检查。

- [ ] **Step 1: 在文件顶部添加 import**

在 `import AgentPrivacyLockCore` 下方加一行：

```swift
import Sparkle
```

- [ ] **Step 2: 在 ClientAppDelegate 中添加 updaterController 属性**

在 `private var policy: CaffeinatePolicy = .full` 下方插入：

```swift
// MARK: - Sparkle Auto-Updater
private var updaterController: SPUStandardUpdaterController?
```

- [ ] **Step 3: 在 applicationDidFinishLaunching 中初始化**

在 `registerHotKey()` 调用**之后**，追加：

```swift
updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)
```

- [ ] **Step 4: 在 rebuildMenu 中添加"检查更新"菜单项**

在 `rebuildMenu()` 方法里，找到 `menu.addItem(NSMenuItem.separator())` 的最后一个（quit 之前），在其**上方**插入：

```swift
let updateItem = NSMenuItem(
    title: "检查更新...",
    action: #selector(checkForUpdates(_:)),
    keyEquivalent: "u"
)
updateItem.target = self
menu.addItem(updateItem)
```

- [ ] **Step 5: 添加 checkForUpdates 方法**

在 `@objc private func quit()` 方法前添加：

```swift
@objc private func checkForUpdates(_ sender: Any) {
    updaterController?.checkForUpdates(sender)
}
```

- [ ] **Step 6: 编译验证**

```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 7: 提交**

```bash
git add Sources/AgentPrivacyLockClient/main.swift
git commit -m "feat: integrate SPUStandardUpdaterController for auto-updates"
```

---

## Task 6: 创建初始 appcast.xml

**Files:**
- Create: `appcast.xml`（repo 根目录）

这是 Sparkle 的 RSS feed。初始版本只有空 channel，不含任何 `<item>`，使 Sparkle 找不到更新（正常，等第一次 release 后才有内容）。

- [ ] **Step 1: 创建 appcast.xml**

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Agent永动机 Updates</title>
    <link>https://github.com/YOUR_GITHUB_OWNER/YOUR_GITHUB_REPO</link>
    <description>Agent永动机 auto-update feed</description>
    <language>zh-cn</language>
    <!-- Items will be added by scripts/release.sh -->
  </channel>
</rss>
```

> 将 `YOUR_GITHUB_OWNER` / `YOUR_GITHUB_REPO` 替换为实际值。

- [ ] **Step 2: 提交**

```bash
git add appcast.xml
git commit -m "feat: add initial empty appcast.xml for Sparkle"
```

---

## Task 7: 创建 release.sh 发布脚本

**Files:**
- Create: `scripts/release.sh`

这是整个发布流水线的入口。调用 `package-internal.sh` 构建 DMG，用 Sparkle 工具生成签名，更新 `appcast.xml`，创建 git tag，推送，用 `gh` CLI 创建 GitHub Release 并上传 DMG。

**前提：** 系统需安装 `gh` CLI（`brew install gh`）并已登录（`gh auth login`）。

- [ ] **Step 1: 创建 scripts/release.sh**

```bash
#!/usr/bin/env bash
# scripts/release.sh — 发布新版本到 GitHub Releases
# 用法: VERSION=1.0.0 BUILD_NUMBER=2 bash scripts/release.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"
SPARKLE_BIN="$SCRIPT_DIR/sparkle-bin/bin"

# ── 配置（与 package-internal.sh 保持一致）──────────────────────────────
APP_NAME="Agent永动机"
GITHUB_OWNER="${GITHUB_OWNER:-YOUR_GITHUB_OWNER}"
GITHUB_REPO="${GITHUB_REPO:-YOUR_GITHUB_REPO}"
VERSION="${VERSION:?需要设置 VERSION 环境变量，例如: VERSION=0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:?需要设置 BUILD_NUMBER 环境变量，例如: BUILD_NUMBER=2}"

DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_PATH="$ROOT_DIR/dist/${APP_NAME}.dmg"
DMG_VERSIONED="$ROOT_DIR/dist/${DMG_NAME}"
APPCAST="$ROOT_DIR/appcast.xml"
TAG="v${VERSION}"

# ── 前置检查 ────────────────────────────────────────────────────────────
echo "==> Checking prerequisites"

if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found. Install: brew install gh" >&2
  exit 1
fi

if [[ ! -x "$SPARKLE_BIN/sign_update" ]]; then
  echo "ERROR: Sparkle CLI tools not found at $SPARKLE_BIN" >&2
  echo "Run Task 1 of the plan to download them." >&2
  exit 1
fi

if git tag -l "$TAG" | grep -q "$TAG"; then
  echo "ERROR: git tag $TAG already exists." >&2
  exit 1
fi

# 确保工作区干净
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: Working tree is dirty. Commit or stash changes first." >&2
  exit 1
fi

# ── 构建 ────────────────────────────────────────────────────────────────
echo "==> Building version $VERSION (build $BUILD_NUMBER)"
VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" \
  bash "$SCRIPT_DIR/package-internal.sh"

# 重命名带版本号（GitHub Release 资产用）
cp "$DMG_PATH" "$DMG_VERSIONED"
echo "    DMG ready: $DMG_VERSIONED"

# ── 生成 EdDSA 签名 ─────────────────────────────────────────────────────
echo "==> Signing DMG with EdDSA"
# sign_update 从 Keychain 读取私钥
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$DMG_VERSIONED")
FILE_SIZE=$(wc -c < "$DMG_VERSIONED" | tr -d ' ')
DOWNLOAD_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${TAG}/${DMG_NAME}"

echo "    Signature: $SIGNATURE"
echo "    Size: $FILE_SIZE bytes"
echo "    Download URL: $DOWNLOAD_URL"

# ── 更新 appcast.xml ─────────────────────────────────────────────────────
echo "==> Updating appcast.xml"
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

# 生成新 <item> 条目
NEW_ITEM=$(cat <<ITEM
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="${DOWNLOAD_URL}"
        sparkle:version="${BUILD_NUMBER}"
        sparkle:shortVersionString="${VERSION}"
        length="${FILE_SIZE}"
        type="application/octet-stream"
        sparkle:edSignature="${SIGNATURE}"
      />
    </item>
ITEM
)

# 将新条目插入到 </channel> 之前（保留旧条目供旧版本检查）
python3 -c "
import sys
content = open('$APPCAST').read()
insertion = '''$NEW_ITEM'''
content = content.replace('    <!-- Items will be added by scripts/release.sh -->', '')
content = content.replace('  </channel>', insertion + '\n  </channel>')
open('$APPCAST', 'w').write(content)
"

echo "    appcast.xml updated"

# ── Git tag + push ──────────────────────────────────────────────────────
echo "==> Committing appcast.xml and tagging $TAG"
git add "$APPCAST"
git commit -m "release: ${TAG}"
git tag "$TAG"
git push
git push origin "$TAG"

# ── GitHub Release ──────────────────────────────────────────────────────
echo "==> Creating GitHub Release $TAG"
gh release create "$TAG" \
  "$DMG_VERSIONED#${APP_NAME} v${VERSION} (DMG)" \
  --title "v${VERSION}" \
  --notes "Version ${VERSION}" \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}"

echo ""
echo "✅ Released ${TAG}"
echo "   Download: $DOWNLOAD_URL"
echo "   appcast:  https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/main/appcast.xml"
```

- [ ] **Step 2: 赋予执行权限**

```bash
chmod +x scripts/release.sh
bash -n scripts/release.sh   # 检查语法
```

Expected: 无输出（无语法错误）。

- [ ] **Step 3: 提交**

```bash
git add scripts/release.sh
git commit -m "feat: add release.sh for Sparkle + GitHub Releases publishing"
```

---

## Task 8: 本地端到端测试

**前提：** 已完成 Task 1–7，并且：
- 已填入真实 `GITHUB_OWNER` / `GITHUB_REPO`
- 已填入真实 `SPARKLE_PUBLIC_KEY`
- `gh auth status` 显示已登录

- [ ] **Step 1: 构建 v0.1.0 并安装**

```bash
VERSION=0.1.0 BUILD_NUMBER=1 bash scripts/package-internal.sh
open dist/Agent永动机.dmg
# 将 Agent永动机.app 拖到 /Applications，然后启动
```

- [ ] **Step 2: 验证菜单栏"检查更新"可点击**

启动 Agent永动机 → 点击菜单栏图标 → 应看到"检查更新..."菜单项。点击后因 appcast 无条目，Sparkle 应提示"已是最新版本"。

- [ ] **Step 3: 发布 v0.2.0**

```bash
# 先确保已推送 main 分支
git push

VERSION=0.2.0 BUILD_NUMBER=2 \
  GITHUB_OWNER=你的用户名 \
  GITHUB_REPO=你的仓库名 \
  bash scripts/release.sh
```

Expected:
```
✅ Released v0.2.0
   Download: https://github.com/.../releases/download/v0.2.0/Agent永动机-v0.2.0.dmg
   appcast:  https://raw.githubusercontent.com/.../main/appcast.xml
```

- [ ] **Step 4: 验证 appcast.xml 可访问**

```bash
curl -s "https://raw.githubusercontent.com/你的用户名/你的仓库名/main/appcast.xml"
# 应看到包含 v0.2.0 的 <item> 条目
```

- [ ] **Step 5: 用 v0.1.0 检测更新**

在 v0.1.0 的 Agent永动机 中：菜单栏 → 检查更新 → Sparkle 应弹出更新对话框，提示"v0.2.0 可用"。

> 如果 Sparkle 弹出"无法验证更新包"的警告，原因是 DMG 是 ad-hoc 签名（非 Developer ID）。这是预期行为。可点击"跳过此版本"或在对话框中手动安装，用于测试 appcast 链路。

- [ ] **Step 6: 提交所有未提交变更**

```bash
git status  # 确认干净
```

---

## 附录：生产环境 Developer ID 签名（可选）

当前方案使用 ad-hoc 签名（`codesign --sign -`），适用于内部分发。若要对外公开发布：

1. **申请 Apple Developer 账号**（$99/年）
2. **在 `package-internal.sh` 中修改签名命令：**
   ```bash
   # 将：
   codesign --force --deep --sign - "$APP_PATH"
   # 改为：
   codesign --force --deep --sign "Developer ID Application: 你的名字 (TEAMID)" \
     --options=runtime --timestamp "$APP_PATH"
   ```
3. **公证：**
   ```bash
   xcrun notarytool submit "$DMG_PATH" \
     --apple-id your@email.com \
     --password app-specific-password \
     --team-id TEAMID --wait
   xcrun stapler staple "$APP_PATH"
   ```
4. **在 `release.sh` 中加入公证步骤**（在生成签名前）。

---

## 自检清单

- [x] **Spec coverage**
  - Sparkle 2.x 集成 ✅ Task 4–5
  - GitHub Releases 托管 ✅ Task 6–7
  - 菜单栏"检查更新" ✅ Task 5
  - 发布脚本 ✅ Task 7
  - 端到端测试 ✅ Task 8
- [x] **No placeholders** — 所有命令和代码均完整
- [x] **Type consistency** — `updaterController` 属性名与方法中引用一致；`SPUStandardUpdaterController` 在 Task 5 统一使用
