#!/bin/bash

# 设置 fork 仓库的脚本

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitHub Fork 设置脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查是否提供了 GitHub 用户名
if [ -z "$1" ]; then
    echo -e "${YELLOW}用法: $0 <your-github-username>${NC}"
    echo ""
    echo "示例:"
    echo "  $0 fei"
    echo ""
    echo "请先完成以下步骤："
    echo "1. 在 GitHub 上 fork 以下仓库："
    echo "   - https://github.com/lyw19b/musl-cross-make"
    echo "   - https://github.com/arceos-org/arceos"
    echo ""
    echo "2. 然后运行此脚本："
    echo "   $0 <your-github-username>"
    exit 1
fi

GITHUB_USER="$1"

echo -e "${GREEN}GitHub 用户名: ${GITHUB_USER}${NC}"
echo ""

# 设置 musl-cross-make
echo -e "${BLUE}[1/2] 设置 musl-cross-make 仓库...${NC}"
cd "$(dirname "${BASH_SOURCE[0]}")"

# 检查是否已经有 upstream
if git remote | grep -q "^upstream$"; then
    echo -e "${YELLOW}  upstream 远程已存在，跳过${NC}"
else
    echo -e "${GREEN}  添加 upstream 远程（原始仓库）...${NC}"
    git remote add upstream https://github.com/lyw19b/musl-cross-make.git
fi

# 更新 origin 指向用户的 fork
echo -e "${GREEN}  更新 origin 指向你的 fork...${NC}"
git remote set-url origin "https://github.com/${GITHUB_USER}/musl-cross-make.git"

echo -e "${GREEN}  验证远程配置...${NC}"
git remote -v

echo ""
echo -e "${YELLOW}  当前本地提交状态：${NC}"
git log --oneline origin/master..HEAD 2>/dev/null || git log --oneline -3

echo ""
echo -e "${BLUE}[2/2] 设置 arceos 仓库...${NC}"
cd ../arceos

# 检查是否已经有 upstream
if git remote | grep -q "^upstream$"; then
    echo -e "${YELLOW}  upstream 远程已存在，跳过${NC}"
else
    echo -e "${GREEN}  添加 upstream 远程（原始仓库）...${NC}"
    git remote add upstream https://github.com/arceos-org/arceos.git
fi

# 更新 origin 指向用户的 fork
echo -e "${GREEN}  更新 origin 指向你的 fork...${NC}"
git remote set-url origin "https://github.com/${GITHUB_USER}/arceos.git"

echo -e "${GREEN}  验证远程配置...${NC}"
git remote -v

echo ""
echo -e "${YELLOW}  当前本地提交状态：${NC}"
git log --oneline origin/main..HEAD 2>/dev/null || git log --oneline -3

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}设置完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "下一步："
echo "1. 确保你已经在 GitHub 上 fork 了这两个仓库"
echo "2. 推送本地提交到你的 fork："
echo ""
echo -e "${BLUE}   cd $(pwd)/../musl-cross-make${NC}"
echo -e "${BLUE}   git push origin master${NC}"
echo ""
echo -e "${BLUE}   cd $(pwd)${NC}"
echo -e "${BLUE}   git push origin main${NC}"
echo ""
echo "3. 以后可以从 upstream 同步更新："
echo -e "${BLUE}   git fetch upstream${NC}"
echo -e "${BLUE}   git merge upstream/master  # 或 upstream/main${NC}"
