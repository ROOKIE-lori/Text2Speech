#!/bin/bash

# 图标和启动页设置脚本
# 使用方法：
# 1. 将去水印后的图片放到 assets/icon/app_icon.png (1024x1024)
# 2. 将去水印后的启动页logo放到 assets/splash/splash_logo.png
# 3. 运行此脚本: bash setup_icons.sh

echo "🎨 开始设置应用图标和启动页..."

# 检查图片文件是否存在
if [ ! -f "assets/icon/app_icon.png" ]; then
    echo "❌ 错误: assets/icon/app_icon.png 不存在"
    echo "   请将去水印后的 1024x1024 图标文件放到该位置"
    exit 1
fi

if [ ! -f "assets/splash/splash_logo.png" ]; then
    echo "⚠️  警告: assets/splash/splash_logo.png 不存在"
    echo "   启动页将只使用绿色背景，不显示logo"
fi

# 安装依赖
echo "📦 安装依赖..."
flutter pub get

# 生成图标
echo "🖼️  生成应用图标..."
flutter pub run flutter_launcher_icons

# 生成启动页
echo "🚀 生成启动页..."
flutter pub run flutter_native_splash:create

echo "✅ 完成！"
echo ""
echo "📱 下一步："
echo "   1. 运行 flutter clean"
echo "   2. 重新构建应用: flutter build apk (Android) 或 flutter build ios (iOS)"
echo "   3. 安装并查看新的图标和启动页"
