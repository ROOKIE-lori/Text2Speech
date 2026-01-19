# File2Speech - 文件转语音应用

一个Vibe Coding项目，基于Flutter开发的多平台文件转语音应用，支持鸿蒙、Android和iOS平台。AI语音模型使用Sherpa-ONNX，目前转换过慢，暂时使用切片转换的方式，后续看如何优化。。。

## 功能特性

- 📄 支持多种文件格式：PDF、TXT等文字文件
- 🎤 高质量中文语音合成（类似微信语音）
- 📱 多平台支持：鸿蒙、Android、iOS
- 🎨 现代化UI设计

## 平台支持

- ✅ HarmonyOS (鸿蒙)
- ✅ Android
- ✅ iOS

## 使用方法

1. 点击"选择文件"按钮上传PDF或TXT文件
2. 系统自动提取文字内容
3. 点击"播放"按钮开始语音播放
4. 使用速度滑块调节播放速度（0.5x - 2.0x）

## 安装和运行

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run
```
