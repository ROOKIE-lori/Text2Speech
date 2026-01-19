# Sherpa-ONNX 原生库集成指南

## 概述

本文档说明如何完成 Sherpa-ONNX 的原生库集成。当前代码已经实现了平台通道框架，但需要编译或获取原生库才能正常工作。

## 当前实现状态

✅ **已完成**：
- Flutter 端平台通道接口（MethodChannel）
- Android 端原生代码框架（Kotlin）
- iOS 端原生代码框架（Swift）
- 模型下载和解压功能
- 自动回退到系统 TTS

⚠️ **待完成**：
- 编译或获取 Sherpa-ONNX 原生库
- 实现 JNI 绑定（Android）
- 实现 Framework 绑定（iOS）
- 完成 TTS 合成逻辑

## 集成步骤

### 方案 1：使用预编译库（推荐）

#### Android

1. **下载预编译的 `.so` 库**：
   ```bash
   # 从 https://github.com/k2-fsa/sherpa-onnx/releases 下载
   # 或从 https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.10.3/sherpa-onnx-1.10.3-android-arm64-v8a.tar.bz2
   ```

2. **解压并放置库文件**：
   ```bash
   # 创建目录
   mkdir -p android/app/src/main/jniLibs/armeabi-v7a
   mkdir -p android/app/src/main/jniLibs/arm64-v8a
   
   # 复制 .so 文件到对应目录
   # libsherpa-onnx.so -> android/app/src/main/jniLibs/armeabi-v7a/
   # libsherpa-onnx.so -> android/app/src/main/jniLibs/arm64-v8a/
   ```

3. **实现 JNI 绑定**：
   在 `MainActivity.kt` 中添加：
   ```kotlin
   init {
       System.loadLibrary("sherpa-onnx")
   }
   
   // 声明 JNI 函数
   external fun sherpaOnnxTtsInit(modelDir: String, modelPath: String): Boolean
   external fun sherpaOnnxTtsSynthesize(text: String, speed: Double): ByteArray
   external fun sherpaOnnxTtsCleanup()
   ```

#### iOS

1. **下载预编译的 Framework**：
   ```bash
   # 从 https://github.com/k2-fsa/sherpa-onnx/releases 下载
   # sherpa-onnx-1.10.3-ios-arm64.tar.bz2
   ```

2. **添加到 Xcode 项目**：
   - 打开 `ios/Runner.xcworkspace`
   - 将 `sherpa-onnx.framework` 拖到项目
   - 在 "General" -> "Frameworks, Libraries, and Embedded Content" 中添加
   - 确保 "Embed & Sign" 已选中

3. **实现 Swift 绑定**：
   在 `AppDelegate.swift` 中添加：
   ```swift
   import sherpa_onnx
   
   // 使用 C 函数调用
   // 需要创建 bridging header 来暴露 C API
   ```

### 方案 2：从源码编译（高级）

#### Android

1. **安装 NDK 和 CMake**：
   ```bash
   # 在 Android Studio 中安装 NDK
   # SDK Manager -> SDK Tools -> NDK (Side by side)
   ```

2. **编译 Sherpa-ONNX**：
   ```bash
   git clone https://github.com/k2-fsa/sherpa-onnx.git
   cd sherpa-onnx
   
   # 参考 https://k2-fsa.github.io/sherpa/onnx/install/install-from-source.html
   # 编译 Android 版本
   ```

3. **集成到项目**：
   - 将编译好的 `.so` 文件复制到 `android/app/src/main/jniLibs/`
   - 配置 CMakeLists.txt（如果需要）

#### iOS

1. **安装依赖**：
   ```bash
   brew install cmake
   ```

2. **编译 Framework**：
   ```bash
   git clone https://github.com/k2-fsa/sherpa-onnx.git
   cd sherpa-onnx
   
   # 编译 iOS 版本
   # 参考官方文档
   ```

3. **集成到项目**：
   - 将编译好的 framework 添加到 Xcode 项目
   - 配置链接设置

## 实现 TTS 合成逻辑

### Android (Kotlin)

在 `MainActivity.kt` 的 `handleSynthesize` 方法中：

```kotlin
private fun handleSynthesize(call: MethodCall, result: MethodChannel.Result) {
    try {
        val text = call.argument<String>("text") ?: ""
        val speed = call.argument<Double>("speed") ?: 1.0
        
        // 调用 JNI 函数
        val audioData = sherpaOnnxTtsSynthesize(text, speed)
        
        // 返回音频数据
        result.success(audioData.toList())
    } catch (e: Exception) {
        result.error("SYNTHESIS_ERROR", e.message, null)
    }
}
```

### iOS (Swift)

在 `AppDelegate.swift` 的 `handleSynthesize` 方法中：

```swift
private func handleSynthesize(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let text = args["text"] as? String,
          let speed = args["speed"] as? Double else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "参数错误", details: nil))
        return
    }
    
    // 调用 C API
    // let audioData = sherpa_onnx_tts_synthesize(text, speed)
    
    // 返回音频数据
    result(Data(audioData))
}
```

## 测试

1. **确保模型已下载**：
   - 在应用中下载模型
   - 确认模型文件存在于应用文档目录

2. **启用 Sherpa-ONNX**：
   - 在 `home_screen.dart` 中设置 `_useSherpaOnnx = true`
   - 或通过 UI 切换

3. **测试 TTS**：
   - 选择文件并提取文字
   - 点击播放按钮
   - 应该使用 Sherpa-ONNX 进行合成

## 故障排除

### Android

- **库加载失败**：检查 `.so` 文件是否在正确的 `jniLibs` 目录
- **JNI 错误**：确保函数签名匹配
- **模型路径错误**：检查模型文件路径是否正确

### iOS

- **Framework 未找到**：检查 framework 是否正确添加到项目
- **链接错误**：检查 "Other Linker Flags" 设置
- **权限问题**：确保应用有文件访问权限

## 参考资源

- [Sherpa-ONNX 官方文档](https://k2-fsa.github.io/sherpa/onnx/index.html)
- [Sherpa-ONNX GitHub](https://github.com/k2-fsa/sherpa-onnx)
- [Sherpa-ONNX TTS C++ API](https://github.com/k2-fsa/sherpa-onnx/tree/master/sherpa-onnx/csrc/tts)
- [Flutter 平台通道文档](https://docs.flutter.dev/platform-integration/platform-channels)

## 注意事项

1. **模型格式**：确保下载的模型格式与库版本兼容
2. **性能**：首次合成可能需要较长时间，建议在后台线程执行
3. **内存**：大模型可能占用较多内存，注意内存管理
4. **线程安全**：确保原生代码的线程安全
