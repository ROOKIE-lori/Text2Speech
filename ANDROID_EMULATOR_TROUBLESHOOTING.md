# Android 模拟器启动问题解决方案

## 当前状态
根据 `flutter doctor`，您的系统配置正常：
- ✅ Android SDK 已安装
- ✅ Android 工具链正常
- ✅ 已有一个模拟器在运行 (emulator-5554)

## 常见问题及解决方案

### 方案 1：关闭已有模拟器并重新启动

如果模拟器启动失败，可能是因为已有进程冲突：

```bash
# 查找并关闭所有模拟器进程
adb devices
adb -s emulator-5554 emu kill

# 或者直接杀掉所有模拟器进程
killall -9 qemu-system-x86_64
killall -9 emulator

# 然后重新启动
flutter emulators --launch Pixel_9_Pro
```

### 方案 2：使用 Android Studio 启动模拟器

1. 打开 Android Studio
2. 点击右上角的设备管理器图标
3. 选择一个模拟器并启动
4. 等待模拟器完全启动后，再运行 Flutter 应用

### 方案 3：检查虚拟化支持（macOS）

确保您的 Mac 支持虚拟化：

```bash
# 检查虚拟化支持
sysctl -a | grep machdep.cpu.features | grep VMX

# 如果输出中包含 VMX，说明支持虚拟化
```

### 方案 4：增加模拟器内存

如果模拟器内存不足，可能导致启动失败：

1. 打开 Android Studio
2. AVD Manager → 编辑模拟器
3. Show Advanced Settings
4. 增加 RAM 和 VM heap 大小（建议至少 2GB RAM）

### 方案 5：清理模拟器缓存

```bash
# 清理模拟器缓存
cd ~/.android/avd
ls -la
# 删除对应的 .avd 文件夹（谨慎操作）
# 然后重新创建模拟器
```

### 方案 6：检查系统资源

确保系统有足够的资源：

```bash
# 检查内存
vm_stat

# 检查磁盘空间
df -h
```

### 方案 7：使用物理设备（推荐用于开发）

如果您有 Android 手机，可以直接连接：

```bash
# 启用 USB 调试后连接手机
adb devices

# 应该能看到您的设备
flutter run -d <device-id>
```

### 方案 8：重新创建模拟器

如果以上方法都不行，可以删除并重新创建模拟器：

1. Android Studio → AVD Manager
2. 删除有问题的模拟器
3. 创建新的模拟器（建议使用 API 33 或 34）

## 快速诊断命令

```bash
# 检查 ADB 连接
adb devices

# 查看模拟器日志
adb -s emulator-5554 logcat

# 检查模拟器状态
flutter devices -v

# 尝试直接启动模拟器（查看详细错误）
emulator -avd Pixel_9_Pro -verbose
```

## 推荐的开发方式

对于 Flutter 开发，推荐使用：
1. **物理设备** - 最可靠，性能最好
2. **iOS 模拟器** - 在 Mac 上性能优秀
3. **Android 模拟器** - 用于测试 Android 平台

```bash
# 直接运行到已连接的设备
flutter run

# 或指定设备
flutter run -d ios        # iOS 模拟器
flutter run -d android    # Android 模拟器
flutter run -d <device-id> # 特定设备
```

## 当前可用的设备

根据 `flutter devices`，您当前有：
- iOS 设备（Lori 和 iPhone）
- macOS
- Android 模拟器（如果成功启动）

建议优先使用 iOS 设备或 Android 模拟器进行开发和测试。
