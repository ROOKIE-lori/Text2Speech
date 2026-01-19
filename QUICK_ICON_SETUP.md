# 快速图标和启动页设置指南

## 方案一：手动替换（最简单，推荐）

### 步骤 1：准备图片

1. **处理原图**（去除水印）：
   - 使用图片编辑工具（Photoshop、GIMP、在线工具如 remove.bg）
   - 去除左上角的 "AI 生成" 和 "#07C160" 水印
   - 去除右下角的 "豆包AI生成" 水印
   - 保持绿色背景 `#07C160` 和中间的白色图标

2. **创建图标文件**：
   - 主图标：1024x1024 像素，PNG 格式，命名为 `app_icon.png`
   - 启动页 logo：建议 1920x1080 或更高，PNG 格式，命名为 `splash_logo.png`

### 步骤 2：放置文件

将处理后的文件放到：
```
assets/
├── icon/
│   └── app_icon.png          # 1024x1024
└── splash/
    └── splash_logo.png       # 启动页logo
```

### 步骤 3：启用插件配置

编辑 `pubspec.yaml`，取消以下配置的注释：

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  flutter_launcher_icons: ^0.13.1  # 取消注释
  flutter_native_splash: ^2.3.10   # 取消注释

flutter:
  uses-material-design: true
  
  assets:  # 取消注释
    - assets/icon/
    - assets/splash/

flutter_launcher_icons:  # 取消注释
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#07C160"
  adaptive_icon_foreground: "assets/icon/app_icon.png"
  remove_alpha_ios: true

flutter_native_splash:  # 取消注释
  color: "#07C160"
  image: "assets/splash/splash_logo.png"
  android: true
  ios: true
  android_12: true
  ios_content_mode: scaleAspectFit
```

### 步骤 4：生成图标和启动页

运行以下命令：

```bash
flutter pub get
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

### 步骤 5：重新构建应用

```bash
flutter clean
flutter build apk  # Android
# 或
flutter build ios  # iOS
```

---

## 方案二：手动替换图标文件（无需插件）

如果您不想使用插件，可以直接手动替换图标文件。

### Android 图标

需要替换以下文件（不同分辨率）：
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (48x48)
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (72x72)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96x96)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144x144)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192x192)

### iOS 图标

需要替换 `ios/Runner/Assets.xcassets/AppIcon.appiconset/` 目录下的所有图标文件。

### 推荐工具

使用在线工具生成所有尺寸：
- [AppIcon.co](https://www.appicon.co/)
- [Icon Kitchen](https://icon.kitchen/)
- [MakeAppIcon](https://makeappicon.com/)

上传您的 1024x1024 图标，工具会自动生成所有需要的尺寸。

---

## 当前状态

✅ Android 启动页已配置为绿色背景（`#07C160`）
✅ 插件配置已准备好（需要取消注释）
✅ assets 目录已创建

❌ 需要您准备去水印的图片文件
❌ 需要运行生成命令

---

## 快速测试

如果您想先测试配置是否正确，可以：

1. 创建一个简单的测试图标（1024x1024，纯绿色背景 `#07C160`）
2. 放到 `assets/icon/app_icon.png`
3. 启用插件配置
4. 运行 `flutter pub run flutter_launcher_icons`

这样可以验证配置是否正确，然后再替换为正式图标。
