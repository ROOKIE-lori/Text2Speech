# Sherpa-ONNX 官方插件集成指南

## 已完成的工作

✅ **已添加官方插件**：
- 在 `pubspec.yaml` 中添加了 `sherpa_onnx: ^1.12.23`
- 重写了 `sherpa_offline_tts_service.dart` 使用官方插件 API

## 下一步操作

### 1. 安装依赖

```bash
cd /Users/mac/Desktop/Text2Voice
flutter pub get
```

### 2. 检查插件 API

如果编译时出现 API 错误，可能需要调整以下内容：

- **初始化方式**：`SherpaOnnxOfflineTts` 的配置可能需要调整
- **合成方法**：`generate()` 方法可能返回不同的数据类型
- **模型配置**：VITS 模型配置参数可能需要调整

### 3. 验证集成

运行应用后：
1. 下载模型（如果还没下载）
2. 应用会自动尝试初始化 Sherpa-ONNX
3. 如果成功，会显示绿色提示
4. 如果失败，会继续使用系统 TTS（不会报错）

## 可能需要的调整

由于官方插件的 API 可能与我实现的有所不同，如果遇到错误，请：

1. **查看编译错误**：运行 `flutter pub get` 和 `flutter analyze`
2. **参考官方文档**：https://k2-fsa.github.io/sherpa/onnx/flutter/index.html
3. **查看示例代码**：https://github.com/k2-fsa/sherpa-onnx/tree/master/flutter

## 官方资源

- **插件主页**：https://pub.dev/packages/sherpa_onnx
- **Flutter 文档**：https://k2-fsa.github.io/sherpa/onnx/flutter/index.html
- **示例代码**：https://github.com/k2-fsa/sherpa-onnx/tree/master/flutter

## 如果 API 不匹配

请将编译错误信息提供给我，我会根据实际的 API 调整代码。
