# Sherpa-ONNX 插件 API 使用指南

## 当前状态

代码框架已准备好，但需要根据实际的 `sherpa_onnx` 插件 API 来调整实现。

## 安装插件

```bash
cd /Users/mac/Desktop/Text2Voice
flutter pub get
```

## 查找插件 API

安装插件后，可以通过以下方式查看 API：

### 方法 1：查看插件源码

```bash
# 查看插件的导出类和方法
find ~/.pub-cache/hosted/pub.dev/sherpa_onnx-*/lib -name "*.dart" | head -5
```

### 方法 2：在 IDE 中查看

1. 在 `lib/services/sherpa_offline_tts_service.dart` 中
2. 取消注释 `import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;`
3. IDE 会自动提示可用的类和变量

### 方法 3：查看官方文档

访问：https://k2-fsa.github.io/sherpa/onnx/flutter/index.html

## 需要调整的代码位置

### 1. 初始化代码（第 62-95 行左右）

```dart
// 需要替换为实际的初始化代码
// 例如：
// _tts = sherpa.SherpaOnnx();
// await _tts.initialize(modelPath: _modelDir!);
```

### 2. 合成代码（第 175-195 行左右）

```dart
// 需要替换为实际的合成代码
// 例如：
// final audioData = await _tts.generate(text: text);
// 或：
// final audioData = await _tts.synthesize(text: text, speed: _currentRate);
```

## 常见 API 模式

根据 Flutter 插件的常见模式，API 可能是：

### 模式 1：类方法
```dart
final tts = SherpaOnnx();
await tts.initialize(modelPath: path);
final audio = await tts.synthesize(text: text);
```

### 模式 2：静态方法
```dart
await SherpaOnnx.initialize(modelPath: path);
final audio = await SherpaOnnx.synthesize(text: text);
```

### 模式 3：配置对象
```dart
final config = SherpaOnnxConfig(...);
final tts = SherpaOnnx(config: config);
final audio = await tts.generate(text: text);
```

## 下一步

1. 运行 `flutter pub get` 安装插件
2. 查看编译错误（如果有）
3. 根据错误信息或 IDE 提示，调整 API 调用
4. 或者将具体的 API 使用方式告诉我，我来帮你调整代码
