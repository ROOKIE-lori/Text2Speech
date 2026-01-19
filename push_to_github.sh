#!/bin/bash

# GitHub 推送脚本
# 使用方法：bash push_to_github.sh YOUR_GITHUB_USERNAME

GITHUB_USERNAME=$1
REPO_NAME="File2Speech"

if [ -z "$GITHUB_USERNAME" ]; then
    echo "❌ 错误: 请提供 GitHub 用户名"
    echo ""
    echo "使用方法:"
    echo "  bash push_to_github.sh YOUR_GITHUB_USERNAME"
    echo ""
    echo "或者手动执行以下命令（将 YOUR_USERNAME 替换为您的 GitHub 用户名）："
    echo "  git remote add origin https://github.com/YOUR_USERNAME/$REPO_NAME.git"
    echo "  git push -u origin main"
    exit 1
fi

echo "🚀 准备推送到 GitHub..."
echo "   用户名: $GITHUB_USERNAME"
echo "   仓库名: $REPO_NAME"
echo ""

# 检查是否已有远程仓库
if git remote | grep -q "^origin$"; then
    echo "⚠️  远程仓库 'origin' 已存在"
    read -p "是否要更新远程仓库地址? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote set-url origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
        echo "✅ 远程仓库地址已更新"
    else
        echo "使用现有的远程仓库地址"
    fi
else
    echo "📡 添加远程仓库..."
    git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
    echo "✅ 远程仓库已添加"
fi

echo ""
echo "📋 当前 Git 状态:"
git status --short | head -5
echo ""

echo "📦 推送分支到 GitHub..."
git branch -M main
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 推送成功！"
    echo "   仓库地址: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
else
    echo ""
    echo "❌ 推送失败"
    echo ""
    echo "可能的原因："
    echo "1. GitHub 仓库尚未创建，请先访问 https://github.com/new 创建仓库"
    echo "2. 网络连接问题"
    echo "3. 身份验证失败，可能需要配置 GitHub 访问令牌"
    echo ""
    echo "如果仓库未创建，请："
    echo "1. 访问 https://github.com/new"
    echo "2. 仓库名称: $REPO_NAME"
    echo "3. 选择 Public 或 Private"
    echo "4. 不要初始化 README、.gitignore 或 license"
    echo "5. 点击 'Create repository'"
    echo "6. 然后重新运行此脚本"
fi
