# GitHub 上传快速指南

## ✅ 当前状态

- ✅ Git 仓库已初始化
- ✅ 所有更改已提交（3 个提交）
- ✅ 代码已准备好上传

## 🚀 快速上传步骤

### 方法一：手动推送（推荐，最简单）

1. **在 GitHub 上创建仓库**（如果还没有）：
   - 访问 https://github.com/new
   - 仓库名称：`File2Speech`
   - 选择 Public 或 Private
   - **不要**初始化 README、.gitignore 或 license
   - 点击 "Create repository"

2. **在终端执行以下命令**（替换 `YOUR_USERNAME` 为您的 GitHub 用户名）：
   ```bash
   cd /Users/mac/Desktop/Text2Voice
   git remote add origin https://github.com/YOUR_USERNAME/File2Speech.git
   git branch -M main
   git push -u origin main
   ```

3. **如果需要身份验证**：
   - 用户名：输入您的 GitHub 用户名
   - 密码：输入 GitHub Personal Access Token（不是登录密码）
   - 生成令牌：https://github.com/settings/tokens
   - 权限选择：`repo`（完整仓库访问权限）

### 方法二：使用推送脚本

1. **在 GitHub 上创建仓库**（同上）

2. **使用 `bash` 运行脚本**（注意：需要使用 `bash` 命令）：
   ```bash
   bash push_to_github.sh YOUR_GITHUB_USERNAME
   ```
   将 `YOUR_GITHUB_USERNAME` 替换为您的 GitHub 用户名。
   
   ⚠️ **注意**：不要直接执行 `push_to_github.sh`，必须使用 `bash push_to_github.sh`。

### 方法二：手动推送

1. **在 GitHub 上创建仓库**：
   - 访问 https://github.com/new
   - 仓库名称：`File2Speech`
   - 不要初始化任何文件

2. **添加远程仓库**：
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/File2Speech.git
   ```

3. **推送到 GitHub**：
   ```bash
   git branch -M main
   git push -u origin main
   ```

## 📊 提交历史

当前有以下提交：

1. `e9d7350` - 更新项目: 改名为File2Speech, 优化TTS分段播放, UI改进
2. `98e20bf` - Update .gitignore and add GitHub upload guide
3. `56c98cc` - Initial commit: Text2Voice app with Sherpa-ONNX TTS support

## ⚠️ 注意事项

1. **如果仓库已存在但远程地址不同**：
   - 脚本会提示是否更新远程地址
   - 或手动执行：`git remote set-url origin https://github.com/YOUR_USERNAME/File2Speech.git`

2. **如果推送失败**：
   - 确保 GitHub 仓库已创建
   - 检查网络连接
   - 如果使用 HTTPS，可能需要配置访问令牌（替代密码）

3. **使用 SSH（可选）**：
   如果已配置 SSH 密钥，可以使用：
   ```bash
   git remote add origin git@github.com:YOUR_USERNAME/File2Speech.git
   git push -u origin main
   ```

## 🔗 相关文件

- `push_to_github.sh` - 自动推送脚本
- `GITHUB_UPLOAD.md` - 详细上传指南
