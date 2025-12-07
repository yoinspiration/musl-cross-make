#!/bin/bash

# 单个架构构建脚本
# 用法: ./build-one.sh <架构名>
# 例如: ./build-one.sh riscv64-linux-musl

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 检查参数
if [ $# -eq 0 ]; then
    log_error "请指定要构建的架构"
    echo ""
    echo "用法: $0 <架构名>"
    echo ""
    echo "支持的架构:"
    echo "  loongarch64-linux-musl"
    echo "  x86_64-linux-musl"
    echo "  aarch64-linux-musl"
    echo "  riscv64-linux-musl"
    echo ""
    exit 1
fi

ARCH=$1

# 验证架构名称
VALID_ARCHS=("loongarch64-linux-musl" "x86_64-linux-musl" "aarch64-linux-musl" "riscv64-linux-musl")
if [[ ! " ${VALID_ARCHS[@]} " =~ " ${ARCH} " ]]; then
    log_error "不支持的架构: $ARCH"
    echo "支持的架构: ${VALID_ARCHS[*]}"
    exit 1
fi

log_info "开始构建架构: $ARCH"
echo ""

# 调用主构建脚本
cd "$(dirname "$0")"
./build-all.sh --arch "$ARCH"

