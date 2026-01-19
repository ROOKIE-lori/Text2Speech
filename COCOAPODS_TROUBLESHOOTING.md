# CocoaPods 安装问题解决方案

如果遇到 `DKImagePickerController` 从 GitHub 克隆超时的问题，可以尝试以下解决方案：

## 方案 1：使用 Flutter 自动安装（推荐）

直接运行 Flutter 应用，Flutter 会自动处理 CocoaPods 安装：

```bash
cd /Users/mac/Desktop/Text2Voice
flutter run -d ios
```

Flutter 会在运行前自动执行 `pod install`。

## 方案 2：配置 GitHub 镜像

如果您在中国大陆，可能需要使用 GitHub 镜像：

```bash
# 使用镜像源（选择一个可用的）
git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/"
# 或者
git config --global url."https://github.com.cnpmjs.org/".insteadOf "https://github.com/"
# 或者  
git config --global url."https://hub.fastgit.xyz/".insteadOf "https://github.com/"

# 然后运行
cd ios
pod install
```

## 方案 3：使用 VPN 或代理

如果您有 VPN 或代理，可以配置 Git 使用：

```bash
# 设置代理（替换为您的代理地址和端口）
git config --global http.proxy http://proxy.example.com:8080
git config --global https.proxy https://proxy.example.com:8080

cd ios
pod install
```

## 方案 4：手动下载依赖

如果上述方法都不行，可以手动克隆仓库：

```bash
cd ~/.cocoapods/repos
git clone https://github.com/zhangao0086/DKImagePickerController.git --branch 4.3.9
cd /Users/mac/Desktop/Text2Voice/ios
pod install
```

## 方案 5：跳过文件选择器功能（临时）

如果您暂时不需要文件选择功能，可以注释掉相关代码，先测试其他功能。

## 当前状态

- ✅ Podfile 已配置 iOS 平台版本（13.0）
- ✅ 项目结构完整
- ⚠️ 需要解决 GitHub 连接问题以完成 CocoaPods 安装

## 推荐操作

最简单的方法是直接运行：
```bash
flutter run -d ios
```

Flutter 会自动处理依赖安装，如果网络有问题，它会提供更详细的错误信息。
