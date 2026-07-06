#!/bin/bash
set -euo pipefail

APP_NAME="GetQClaw"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> 清理旧构建..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

SDK_PATH=$(xcrun --show-sdk-path)
echo "==> SDK: $SDK_PATH"

echo "==> 编译 C 桥接层..."
clang -c Sources/crypto_bridge.c -o "$BUILD_DIR/crypto_bridge.o" \
    -isysroot "$SDK_PATH" \
    -mmacosx-version-min=14.0

echo "==> 编译 Swift..."
swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -sdk "$SDK_PATH" \
    -target arm64-apple-macos14.0 \
    -framework SwiftUI \
    -framework AppKit \
    -framework Security \
    -framework Foundation \
    -import-objc-header BridgingHeader.h \
    Sources/App.swift \
    Sources/Models.swift \
    Sources/CryptoUtils.swift \
    Sources/APIClient.swift \
    Sources/QClawService.swift \
    Sources/Views/ContentView.swift \
    Sources/Views/ApiKeyView.swift \
    Sources/Views/ModelsView.swift \
    Sources/Views/BalanceView.swift \
    "$BUILD_DIR/crypto_bridge.o"

echo "==> 打包 .app 捆绑包..."
cp Info.plist "$CONTENTS_DIR/"
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo ""
echo "============================================"
echo "  ✅ 构建完成"
echo "  $APP_BUNDLE"
echo "============================================"
echo ""
echo "  运行方式:"
echo "    open $APP_BUNDLE"
echo ""
echo "  或拖入 /Applications 后从启动台打开。"
echo "  首次运行需要在 Keychain 弹窗中允许访问。"
echo ""