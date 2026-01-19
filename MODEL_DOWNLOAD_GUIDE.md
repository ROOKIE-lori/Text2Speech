# 模型动态下载功能使用指南

## 功能概述

本应用支持动态下载 Sherpa-ONNX TTS 模型，实现离线语音合成功能。

## 实现的功能

### 1. 模型管理类 (`ModelManager`)

**文件位置**: `lib/services/model_manager.dart`

**主要功能**:
- ✅ 模型下载（使用 `dio` 插件）
- ✅ 下载进度监控
- ✅ 模型解压（使用 `archive` 插件）
- ✅ 模型文件校验
- ✅ 模型路径管理
- ✅ 异常处理（网络错误、存储空间不足等）

**主要方法**:
- `isModelDownloaded()`: 检查模型是否已下载
- `downloadModel()`: 下载模型文件，支持进度回调和取消
- `getModelFilePath()`: 获取模型文件路径
- `deleteModel()`: 删除模型文件

### 2. Sherpa-ONNX TTS 服务 (`SherpaOfflineTTSService`)

**文件位置**: `lib/services/sherpa_offline_tts_service.dart`

**主要功能**:
- ✅ 从本地文件路径初始化模型
- ✅ 检查模型是否已下载
- ✅ 语音合成接口（需要实现实际的合成逻辑）
- ✅ 音频播放（使用 `audioplayers`）
- ✅ 进度追踪

**注意**: `_synthesizeSpeech()` 方法需要实现实际的 sherpa-onnx TTS 合成逻辑。

### 3. 模型下载 UI 组件 (`ModelDownloadWidget`)

**文件位置**: `lib/widgets/model_download_widget.dart`

**UI 功能**:
- ✅ 状态显示（未下载/下载中/已就绪/错误）
- ✅ 实时进度条显示下载百分比
- ✅ 操作按钮（下载/取消/重试）
- ✅ 错误信息显示
- ✅ 删除模型功能

**状态类型**:
- `checking`: 检查模型状态
- `notDownloaded`: 模型未下载
- `downloading`: 下载中
- `ready`: 模型已就绪
- `error`: 下载错误

## 使用方法

### 1. 配置模型下载地址

在 `ModelManager` 构造函数中设置模型下载地址：

```dart
final modelManager = ModelManager(
  downloadUrl: 'https://your-server.com/vits-zh-model.zip',
);
```

### 2. 启用 Sherpa-ONNX

在主界面中，设置 `_useSherpaOnnx = true` 以显示模型下载组件：

```dart
bool _useSherpaOnnx = true; // 设置为 true 启用
```

### 3. 切换 TTS 服务

在 `home_screen.dart` 中，可以根据模型状态切换使用不同的 TTS 服务：

```dart
// 检查模型是否已下载
final isModelReady = await _sherpaTtsService.isModelDownloaded();

if (isModelReady) {
  // 使用 Sherpa-ONNX
  await _sherpaTtsService.speak(text);
} else {
  // 使用 flutter_tts
  await _ttsService.speak(text);
}
```

## 模型文件结构

下载的 zip 文件解压后应包含以下结构：

```
sherpa-onnx-tts-model/
  ├── model.onnx          # 主模型文件（必需）
  ├── tokens.txt          # 词汇表（可选）
  └── ...                 # 其他配置文件
```

## 异常处理

已实现的异常处理：

1. **网络错误**:
   - 连接超时
   - 网络断开
   - 下载中断

2. **存储错误**:
   - 存储空间不足（由系统抛出）
   - 文件写入失败

3. **解压错误**:
   - zip 文件损坏
   - 解压失败

4. **校验错误**:
   - 模型文件不存在
   - 模型文件为空

## 下一步工作

### 需要实现的部分

1. **Sherpa-ONNX 合成逻辑**:
   - 实现 `_synthesizeSpeech()` 方法
   - 使用 FFI 调用原生库，或
   - 使用平台通道调用原生代码

2. **原生库集成**:
   - Android: 将 `libsherpa-onnx.so` 添加到 `android/app/src/main/jniLibs/`
   - iOS: 将 framework 添加到 Xcode 项目

3. **模型文件**:
   - 准备模型下载服务器
   - 或使用 CDN 托管模型文件

## 测试建议

1. **下载测试**:
   - 测试正常下载流程
   - 测试下载中断和恢复
   - 测试网络错误处理

2. **解压测试**:
   - 测试正常解压
   - 测试损坏的 zip 文件

3. **UI 测试**:
   - 测试各种状态的显示
   - 测试进度条更新
   - 测试按钮交互

## 注意事项

- 模型文件通常较大（几十到几百 MB），下载需要时间
- 建议在 Wi-Fi 环境下下载
- 确保设备有足够的存储空间
- 首次下载后，模型会保存在本地，后续无需重新下载
