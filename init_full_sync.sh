#!/usr/bin/env bash
# =======================================================
# 🚀 MkDocs 全自动同步构建脚本（跨平台自愈版）
# 适用于 macOS / Windows (Git Bash) / Linux
# 作者: Leo Chiang (bigprc.com)
# =======================================================

set -e

echo "🌍 正在初始化全流程环境..."
echo "------------------------------------------"

# 检测系统类型
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
  *darwin*) OS_TYPE="macOS" ;;
  *linux*)  OS_TYPE="Linux" ;;
  *mingw*|*msys*) OS_TYPE="Windows" ;;
  *) OS_TYPE="Unknown" ;;
esac

echo "🖥 检测到系统类型：$OS_TYPE"

# Step 1: 检查 Git
if ! command -v git &>/dev/null; then
  echo "❌ 未检测到 Git，请先安装 Git。"
  exit 1
fi

# Step 2: 拉取远程最新代码
echo "📡 正在从远程仓库拉取最新代码..."
git fetch origin main

# 若有未提交更改，自动暂存
if [[ -n $(git status --porcelain) ]]; then
  echo "⚠️ 检测到未提交改动，自动暂存中..."
  git add .
  git stash save "auto-save-before-sync" >/dev/null 2>&1 || true
fi

# 尝试自动 rebase 拉取
if ! git pull --rebase origin main; then
  echo "⚠️ 自动合并失败，尝试强制解决冲突..."
  git merge --strategy-option=theirs origin/main || true
fi

# 检查 CNAME 冲突并保留远程版本
if git ls-files --unmerged | grep -q "CNAME"; then
  echo "⚙️ 检测到 CNAME 冲突，保留远程版本..."
  git checkout --theirs CNAME
  git add CNAME
  git commit -m "fix: auto-resolve CNAME conflict" || true
fi

git stash pop >/dev/null 2>&1 || true

echo "✅ 代码同步完成。"

# Step 3: 检查 Python
if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
  echo "❌ 未检测到 Python，请先安装 Python 3.8+。"
  exit 1
fi

PYTHON=$(command -v python3 || command -v python)
echo "🐍 检测到 Python 路径：$PYTHON"

# Step 4: 创建虚拟环境
if [ ! -d "venv" ]; then
  echo "📦 创建虚拟环境..."
  $PYTHON -m venv venv
fi

# Step 5: 激活虚拟环境（跨平台兼容）
if [[ "$OS_TYPE" == "Windows" ]]; then
  source venv/Scripts/activate
else
  source venv/bin/activate
fi

# Step 6: 确保 pip 可用
echo "📦 检查 pip ..."
$PYTHON -m ensurepip --upgrade >/dev/null 2>&1 || true
$PYTHON -m pip install --upgrade pip >/dev/null 2>&1

# Step 7: 安装依赖
echo "🔧 安装/更新 MkDocs 依赖..."
pip install -q --upgrade mkdocs mkdocs-material mkdocs-git-revision-date-localized-plugin mkdocs-minify-plugin

# Step 8: 构建网站
echo "🏗 正在构建 MkDocs 网站..."
mkdocs build --clean

# Step 9: 部署推送
echo "🚀 推送构建结果到远程仓库..."
git add .
git commit -m "auto: sync & rebuild at $(date '+%Y-%m-%d %H:%M:%S')" || true
git push origin main

# Step 10: 构建完成提示
echo "------------------------------------------"
echo "✅ 同步、构建、推送全部完成！"
echo "🌐 你的网站已更新至 GitHub Pages。"
echo "------------------------------------------"
