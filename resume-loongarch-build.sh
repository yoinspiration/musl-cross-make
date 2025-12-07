#!/bin/bash

# 继续构建 LoongArch 工具链

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

ARCH="loongarch64-linux-musl"
BUILD_DIR="build/local/${ARCH}"

echo "=========================================="
log_info "继续构建 LoongArch 工具链"
echo "=========================================="
echo ""

# 检查构建目录
if [ ! -d "$BUILD_DIR" ]; then
    log_error "构建目录不存在: $BUILD_DIR"
    log_info "请先运行: ./build-all.sh --arch $ARCH"
    exit 1
fi

# 检查 Makefile
if [ ! -f "$BUILD_DIR/Makefile" ]; then
    log_error "Makefile 不存在"
    exit 1
fi

log_info "构建目录: $BUILD_DIR"
log_info "继续构建..."
echo ""

# 进入构建目录并继续构建
cd "$BUILD_DIR"

# 检查是否有输出目录配置
if [ -f "../config.mak" ] || [ -f "../../../config.mak" ]; then
    log_info "找到配置文件"
fi

# 继续构建（make 会自动从上次停止的地方继续）
log_info "运行 make 继续构建..."
if make -j$(sysctl -n hw.ncpu 2>/dev/null || echo 4); then
    echo ""
    log_info "构建完成！"
    echo ""
    log_info "现在运行安装:"
    echo "  cd $BUILD_DIR"
    echo "  make OUTPUT=../../../output install"
    echo ""
    log_info "或者从项目根目录运行:"
    echo "  make install"
else
    echo ""
    log_error "构建失败"
    echo ""
    log_info "查看错误信息，然后可以:"
    echo "  1. 修复问题后重新运行此脚本"
    echo "  2. 或者清理后重新构建: rm -rf $BUILD_DIR"
    exit 1
fi
