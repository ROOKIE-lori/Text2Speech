# Sherpa-ONNX 原生库集成快速指南

## 第一步：下载预编译库

### Android

1. 访问 https://github.com/k2-fsa/sherpa-onnx/releases
2. 下载最新版本的 Android 库（例如：`sherpa-onnx-1.10.3-android-arm64-v8a.tar.bz2`）
3. 解压并复制 `.so` 文件：

```bash
# 创建目录
mkdir -p android/app/src/main/jniLibs/arm64-v8a
mkdir -p android/app/src/main/jniLibs/armeabi-v7a

# 解压下载的文件，然后将 libsherpa-onnx*.so 复制到对应目录
# 注意：可能需要多个 .so 文件（包括依赖库）
```

### iOS

1. 访问 https://github.com/k2-fsa/sherpa-onnx/releases  
2. 下载最新版本的 iOS 框架（例如：`sherpa-onnx-1.10.3-ios-arm64.tar.bz2`）
3. 解压得到 `SherpaOnnx.xcframework`
4. 在 Xcode 中添加到项目（见下面的步骤）

## 第二步：配置项目

### Android - 更新 build.gradle

已配置：`ndk { abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64' }`

### iOS - 添加 Framework

1. 打开 `ios/Runner.xcworkspace`（注意：是 .xcworkspace，不是 .xcodeproj）
2. 将 `SherpaOnnx.xcframework` 拖到项目
3. 选择 "Copy items if needed"
4. 在 Runner target 的 "General" -> "Frameworks, Libraries, and Embedded Content" 中添加
5. 确保选择 "Embed & Sign"

## 第三步：实现原生代码

代码已经准备好了：
- Android: `android/app/src/main/kotlin/com/example/text2voice/MainActivity.kt`
- iOS: `ios/Runner/AppDelegate.swift`

你只需要：
1. 下载原生库文件
2. 放置到正确位置
3. 重新编译应用

## 测试

1. 下载模型（在应用中）
2. 应用会自动尝试初始化 Sherpa-ONNX
3. 如果成功，会显示绿色提示
4. 如果失败，会继续使用系统 TTS（不会报错）
