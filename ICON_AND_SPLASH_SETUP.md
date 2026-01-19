# 应用图标和启动页设置指南

本文档说明如何将新的设计图片（绿色背景 + 白色文档图标）设置为应用的图标和启动页logo。

## 设计规格

根据您的描述，图标设计为：
- **背景色**：`#07C160`（微信绿色）
- **图标元素**：白色文档/文件夹图标，带有 "Ai" 文字和Wi-Fi图标
- **需要去除**：左上角的 "AI 生成" 和 "#07C160" 水印，右下角的 "豆包AI生成" 水印

## 步骤 1：准备图标文件

### 1.1 图片处理

首先，您需要使用图片编辑工具（如 Photoshop、GIMP、或在线工具）：
1. 打开原图片
2. 去除水印部分（左上角和右下角）
3. 确保图标居中，背景为纯色 `#07C160`

### 1.2 生成不同尺寸的图标

#### Android 需要的图标尺寸：
- `mipmap-mdpi`: 48x48 px
- `mipmap-hdpi`: 72x72 px  
- `mipmap-xhdpi`: 96x96 px
- `mipmap-xxhdpi`: 144x144 px
- `mipmap-xxxhdpi`: 192x192 px

#### iOS 需要的图标尺寸：
- `Icon-App-20x20@1x`: 20x20 px
- `Icon-App-20x20@2x`: 40x40 px
- `Icon-App-20x20@3x`: 60x60 px
- `Icon-App-29x29@1x`: 29x29 px
- `Icon-App-29x29@2x`: 58x58 px
- `Icon-App-29x29@3x`: 87x87 px
- `Icon-App-40x40@1x`: 40x40 px
- `Icon-App-40x40@2x`: 80x80 px
- `Icon-App-40x40@3x`: 120x120 px
- `Icon-App-60x60@2x`: 120x120 px
- `Icon-App-60x60@3x`: 180x180 px
- `Icon-App-76x76@1x`: 76x76 px
- `Icon-App-76x76@2x`: 152x152 px
- `Icon-App-83.5x83.5@2x`: 167x167 px
- `Icon-App-1024x1024@1x`: 1024x1024 px（必需）

### 1.3 推荐工具

您可以使用以下工具生成所有尺寸的图标：

1. **在线工具**：
   - [AppIcon.co](https://www.appicon.co/) - 自动生成所有尺寸
   - [Icon Kitchen](https://icon.kitchen/) - Google 官方工具
   - [MakeAppIcon](https://makeappicon.com/) - 一键生成

2. **Flutter 插件**：
   ```bash
   flutter pub add flutter_launcher_icons
   ```

## 步骤 2：替换 Android 图标

### 2.1 手动替换

将生成的图标文件按以下路径放置：

```
android/app/src/main/res/
├── mipmap-mdpi/
│   └── ic_launcher.png (48x48)
├── mipmap-hdpi/
│   └── ic_launcher.png (72x72)
├── mipmap-xhdpi/
│   └── ic_launcher.png (96x96)
├── mipmap-xxhdpi/
│   └── ic_launcher.png (144x144)
└── mipmap-xxxhdpi/
    └── ic_launcher.png (192x192)
```

### 2.2 使用 flutter_launcher_icons 插件（推荐）

在 `pubspec.yaml` 中添加配置：

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"  # 1024x1024 的主图标
  adaptive_icon_background: "#07C160"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```

然后运行：
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

## 步骤 3：替换 iOS 图标

### 3.1 手动替换

将所有图标文件复制到：
```
ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

### 3.2 使用 flutter_launcher_icons 插件

如果使用插件，会自动生成所有 iOS 图标。

## 步骤 4：配置启动页（Splash Screen）

### 4.1 Android 启动页

启动页配置在 `android/app/src/main/res/drawable/launch_background.xml` 中，当前配置为：
- 背景色：白色
- 居中显示应用图标

如果需要修改为绿色背景，可以：

**选项 A：使用绿色背景 + 图标**
```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 绿色背景 -->
    <item>
        <color android:color="#07C160" />
    </item>
    <!-- 居中显示图标 -->
    <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/ic_launcher" />
    </item>
</layer-list>
```

**选项 B：使用自定义启动图片**

1. 创建启动图片（去掉水印的原图）
2. 放在 `android/app/src/main/res/drawable/launch_logo.png`
3. 修改 `launch_background.xml`：
```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <color android:color="#07C160" />
    </item>
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/launch_logo" />
    </item>
</layer-list>
```

### 4.2 iOS 启动页

iOS 启动页在 `ios/Runner/Base.lproj/LaunchScreen.storyboard` 中配置。

**使用 flutter_native_splash 插件（推荐）**：

```bash
flutter pub add flutter_native_splash
```

在 `pubspec.yaml` 中添加：
```yaml
flutter_native_splash:
  color: "#07C160"
  image: "assets/splash/splash_logo.png"  # 启动页logo（去水印的图片）
  android: true
  ios: true
  android_12: true
  ios_content_mode: scaleAspectFit
```

然后运行：
```bash
flutter pub get
flutter pub run flutter_native_splash:create
```

## 步骤 5：验证

1. **清理构建缓存**：
   ```bash
   flutter clean
   ```

2. **重新构建**：
   ```bash
   flutter build apk  # Android
   flutter build ios  # iOS
   ```

3. **测试**：
   - Android：安装 APK 查看桌面图标和启动页
   - iOS：在 Xcode 中运行查看图标和启动页

## 注意事项

1. **图标格式**：必须为 PNG 格式，不支持透明度
2. **圆角**：Android 和 iOS 会自动应用圆角
3. **自适应图标**：Android 8.0+ 支持自适应图标，建议配置 `adaptive_icon_foreground` 和 `adaptive_icon_background`
4. **启动页尺寸**：建议使用与设备分辨率匹配的图片，或使用矢量图

## 快速开始（使用插件）

如果您想快速设置，推荐使用插件：

1. 准备一个 1024x1024 的主图标（去水印后）
2. 可选：准备启动页 logo（去水印后）

3. 在 `pubspec.yaml` 中添加：
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1
  flutter_native_splash: ^2.3.10

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#07C160"
  remove_alpha_ios: true

flutter_native_splash:
  color: "#07C160"
  image: "assets/splash/splash_logo.png"
  android: true
  ios: true
  android_12: true
  ios_content_mode: scaleAspectFit
```

4. 运行命令：
```bash
flutter pub get
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

## 文件结构示例

```
assets/
├── icon/
│   └── app_icon.png          # 1024x1024 主图标（去水印）
└── splash/
    └── splash_logo.png       # 启动页logo（去水印，建议 1920x1080 或更高）
```
