#!/usr/bin/env bash
# scripts/release.sh — 发布新版本到 GitHub Releases
# 用法: VERSION=0.2.0 BUILD_NUMBER=2 bash scripts/release.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"
SPARKLE_BIN="$SCRIPT_DIR/sparkle-bin/bin"

# ── 配置 ────────────────────────────────────────────────────────────────
APP_NAME="Agent永动机"
GITHUB_OWNER="${GITHUB_OWNER:-Bbbtt04}"
GITHUB_REPO="${GITHUB_REPO:-screensaver}"
VERSION="${VERSION:?需要设置 VERSION 环境变量，例如: VERSION=0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:?需要设置 BUILD_NUMBER 环境变量，例如: BUILD_NUMBER=2}"

DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_SRC="$ROOT_DIR/dist/${APP_NAME}.dmg"
DMG_VERSIONED="$ROOT_DIR/dist/${DMG_NAME}"
APPCAST="$ROOT_DIR/appcast.xml"
TAG="v${VERSION}"

# ── 前置检查 ────────────────────────────────────────────────────────────
echo "==> Checking prerequisites"

if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found. Install: brew install gh && gh auth login" >&2
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

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: Working tree is dirty. Commit or stash changes first." >&2
  exit 1
fi

# ── 构建 DMG ─────────────────────────────────────────────────────────────
echo "==> Building version $VERSION (build $BUILD_NUMBER)"
VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" \
  GITHUB_OWNER="$GITHUB_OWNER" GITHUB_REPO="$GITHUB_REPO" \
  bash "$SCRIPT_DIR/package-internal.sh"

cp "$DMG_SRC" "$DMG_VERSIONED"
echo "    DMG: $DMG_VERSIONED"

# ── EdDSA 签名 ────────────────────────────────────────────────────────────
echo "==> Signing DMG with EdDSA (reads private key from Keychain)"
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$DMG_VERSIONED")
FILE_SIZE=$(wc -c < "$DMG_VERSIONED" | tr -d ' ')
DOWNLOAD_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${TAG}/${DMG_NAME}"

echo "    Signature: $SIGNATURE"
echo "    Size:      $FILE_SIZE bytes"
echo "    URL:       $DOWNLOAD_URL"

# ── 更新 appcast.xml ─────────────────────────────────────────────────────
echo "==> Updating appcast.xml"
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

python3 - <<PYEOF
content = open("$APPCAST").read()
item = """    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="$DOWNLOAD_URL"
        sparkle:version="$BUILD_NUMBER"
        sparkle:shortVersionString="$VERSION"
        length="$FILE_SIZE"
        type="application/octet-stream"
        sparkle:edSignature="$SIGNATURE"
      />
    </item>"""
# Remove placeholder comment if present
content = content.replace("    <!-- Items will be added by scripts/release.sh -->", "")
# Insert before closing </channel>
content = content.replace("  </channel>", item + "\n  </channel>")
open("$APPCAST", "w").write(content)
PYEOF

echo "    appcast.xml updated with $TAG"

# ── Git commit + tag + push ───────────────────────────────────────────────
echo "==> Committing appcast.xml and tagging $TAG"
git add "$APPCAST"
git commit -m "release: $TAG"
git tag "$TAG"
git push
git push origin "$TAG"

# ── GitHub Release ────────────────────────────────────────────────────────
echo "==> Creating GitHub Release $TAG"
gh release create "$TAG" \
  "$DMG_VERSIONED#${APP_NAME} v${VERSION} (DMG)" \
  --title "v${VERSION}" \
  --notes "Version ${VERSION}" \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}"

echo ""
echo "✅ Released $TAG"
echo "   Download: $DOWNLOAD_URL"
echo "   Appcast:  https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/main/appcast.xml"
