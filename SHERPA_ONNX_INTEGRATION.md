# Sherpa-ONNX 集成指南

## 概述

Sherpa-ONNX 是一个基于 ONNX Runtime 的高性能语音处理工具包，支持离线语音合成（TTS）。本项目将使用 sherpa-onnx 替换原有的 flutter_tts。

**重要提示**：sherpa-onnx 的完整集成需要原生开发经验，包括：
- 编译或获取原生库（C++）
- 实现 FFI 绑定或平台通道
- 下载和配置模型文件（通常几十到几百 MB）

## 推荐方案：使用 WebSocket 服务器

由于直接集成原生库较复杂，推荐使用 **WebSocket 服务器方案**：

### 方案 1：本地 WebSocket 服务器（推荐）

1. **启动本地 sherpa-onnx 服务器**：
   ```bash
   # 从 https://github.com/k2-fsa/sherpa-onnx/releases 下载预编译的服务器
   ./sherpa-onnx-tts-server --model-dir=/path/to/model
   ```

2. **在 Flutter 中连接服务器**：
   - 使用 `web_socket_channel` 包连接本地服务器
   - 发送文本，接收音频数据
   - 使用 `audioplayers` 播放音频

### 方案 2：直接集成原生库（复杂）

如果需要完全离线运行，需要：

#### 1. 下载模型文件

从 [sherpa-onnx 模型仓库](https://github.com/k2-fsa/sherpa-onnx/releases) 下载中文 TTS 模型：

- 推荐模型：`vits-zh` 或 `vits-zh-aishell3`
- 下载地址：https://github.com/k2-fsa/sherpa-onnx/releases

将模型文件解压到应用文档目录。

#### 2. 添加依赖

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  ffi: ^2.1.0
  path_provider: ^2.1.1
  audioplayers: ^5.2.1
  web_socket_channel: ^2.4.0  # 如果使用 WebSocket 方案
```

#### 3. 配置原生库

**Android**:
- 下载预编译的 `.so` 库文件
- 放置到 `android/app/src/main/jniLibs/armeabi-v7a/` 和 `arm64-v8a/` 目录

**iOS**:
- 使用 CocoaPods 或手动添加 framework
- 配置 Xcode 项目链接库

#### 4. 实现 FFI 绑定或平台通道

- **FFI 方案**：使用 `dart:ffi` 直接调用 C++ API（复杂）
- **平台通道方案**：在原生代码中封装 sherpa-onnx，通过 MethodChannel 调用（推荐）

## 当前实现状态

已创建以下文件：
- `lib/services/sherpa_tts_service.dart` - Sherpa-ONNX TTS 服务框架
- `lib/services/tts_service_adapter.dart` - TTS 服务适配器（可在不同实现间切换）

**注意**：`sherpa_tts_service.dart` 中的 `_synthesizeSpeech` 方法需要实现实际的合成逻辑。

## 快速开始（WebSocket 方案）

1. 下载并启动 sherpa-onnx 服务器
2. 修改 `sherpa_tts_service.dart` 中的 `_synthesizeSpeech` 方法，使用 WebSocket 连接服务器
3. 在 `tts_service_adapter.dart` 中切换到 `SherpaTTSService`

## 参考资源

- [Sherpa-ONNX 官方文档](https://k2-fsa.github.io/sherpa/onnx/index.html)
- [Sherpa-ONNX GitHub](https://github.com/k2-fsa/sherpa-onnx)
- [Sherpa-ONNX TTS 示例](https://github.com/k2-fsa/sherpa-onnx/tree/master/sherpa-onnx/csrc/tts)
