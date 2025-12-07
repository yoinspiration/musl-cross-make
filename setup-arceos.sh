#!/bin/bash

# 配置 ArceOS 使用我们构建的 musl 工具链

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

log_check() {
    echo -e "${BLUE}[检查]${NC} $1"
}

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MUSL_DIR="$SCRIPT_DIR"
ARCEOS_DIR="${SCRIPT_DIR%/*}/arceos"

echo "=========================================="
log_info "配置 ArceOS 使用 musl 工具链"
echo "=========================================="
echo ""

# 1. 检查工具链
log_check "检查 musl 工具链..."
ARCHITECTURES=("loongarch64-linux-musl" "x86_64-linux-musl" "aarch64-linux-musl" "riscv64-linux-musl")
MISSING_TOOLCHAINS=()

for arch in "${ARCHITECTURES[@]}"; do
    toolchain_dir="${MUSL_DIR}/output-${arch}"
    if [ -d "$toolchain_dir" ]; then
        log_info "✓ $arch 工具链存在: $toolchain_dir"
    else
        log_warn "✗ $arch 工具链不存在: $toolchain_dir"
        MISSING_TOOLCHAINS+=("$arch")
    fi
done

if [ ${#MISSING_TOOLCHAINS[@]} -gt 0 ]; then
    log_error "缺少以下工具链: ${MISSING_TOOLCHAINS[*]}"
    log_info "请先运行: ./build-all.sh --arch <架构>"
    exit 1
fi

# 2. 检查 ArceOS 仓库
log_check "检查 ArceOS 仓库..."
if [ ! -d "$ARCEOS_DIR" ]; then
    log_warn "ArceOS 目录不存在: $ARCEOS_DIR"
    log_info "是否要克隆 ArceOS 仓库？(y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "克隆 ArceOS 仓库..."
        cd "${ARCEOS_DIR%/*}"
        git clone https://github.com/arceos-org/arceos.git
        cd "$ARCEOS_DIR"
    else
        log_error "请先克隆 ArceOS 仓库或设置正确的路径"
        exit 1
    fi
else
    log_info "✓ ArceOS 目录存在: $ARCEOS_DIR"
fi

# 3. 检查 Rust 工具
log_check "检查 Rust 工具..."
if ! command -v cargo >/dev/null 2>&1; then
    log_error "未找到 cargo，请先安装 Rust:"
    log_info "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

log_info "✓ cargo 已安装"

# 检查必要的 Rust 工具
RUST_TOOLS=("cargo-binutils" "axconfig-gen" "cargo-axplat")
MISSING_RUST_TOOLS=()

for tool in "${RUST_TOOLS[@]}"; do
    if cargo install --list 2>/dev/null | grep -q "^$tool"; then
        log_info "✓ $tool 已安装"
    else
        log_warn "✗ $tool 未安装"
        MISSING_RUST_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_RUST_TOOLS[@]} -gt 0 ]; then
    log_info "安装缺失的 Rust 工具..."
    for tool in "${MISSING_RUST_TOOLS[@]}"; do
        log_info "安装 $tool..."
        cargo install "$tool" || log_warn "安装 $tool 失败，可能需要手动安装"
    done
fi

# 4. 检查 QEMU
log_check "检查 QEMU..."
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    log_warn "QEMU 未安装"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "在 macOS 上安装 QEMU:"
        log_info "  brew install qemu"
    else
        log_info "请安装 QEMU:"
        log_info "  sudo apt-get install qemu-system"
    fi
else
    log_info "✓ QEMU 已安装"
    qemu-system-x86_64 --version | head -1
fi

# 5. 创建工具链配置脚本
log_check "创建工具链配置脚本..."
CONFIG_SCRIPT="${ARCEOS_DIR}/setup-musl-toolchain.sh"

cat > "$CONFIG_SCRIPT" << 'EOF'
#!/bin/bash
# ArceOS musl 工具链配置脚本
# 由 setup-arceos.sh 自动生成

# 获取 musl-cross-make 目录（假设在 arceos 的父目录）
MUSL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../musl-cross-make" && pwd)"

# 设置工具链路径
export PATH="${MUSL_DIR}/output-loongarch64-linux-musl/bin:${PATH}"
export PATH="${MUSL_DIR}/output-x86_64-linux-musl/bin:${PATH}"
export PATH="${MUSL_DIR}/output-aarch64-linux-musl/bin:${PATH}"
export PATH="${MUSL_DIR}/output-riscv64-linux-musl/bin:${PATH}"

# 设置架构特定的环境变量
export LOONGARCH64_TOOLCHAIN="${MUSL_DIR}/output-loongarch64-linux-musl"
export X86_64_TOOLCHAIN="${MUSL_DIR}/output-x86_64-linux-musl"
export AARCH64_TOOLCHAIN="${MUSL_DIR}/output-aarch64-linux-musl"
export RISCV64_TOOLCHAIN="${MUSL_DIR}/output-riscv64-linux-musl"

echo "Musl 工具链已配置"
echo "工具链路径:"
echo "  loongarch64: ${LOONGARCH64_TOOLCHAIN}"
echo "  x86_64:      ${X86_64_TOOLCHAIN}"
echo "  aarch64:     ${AARCH64_TOOLCHAIN}"
echo "  riscv64:     ${RISCV64_TOOLCHAIN}"
EOF

chmod +x "$CONFIG_SCRIPT"
log_info "✓ 已创建配置脚本: $CONFIG_SCRIPT"

# 6. 创建构建辅助脚本
log_check "创建构建辅助脚本..."
BUILD_SCRIPT="${ARCEOS_DIR}/build-with-musl.sh"

cat > "$BUILD_SCRIPT" << 'EOF'
#!/bin/bash
# 使用 musl 工具链构建 ArceOS

# 加载工具链配置
source "$(dirname "${BASH_SOURCE[0]}")/setup-musl-toolchain.sh"

# 默认参数
ARCH="${1:-x86_64}"
APP="${2:-examples/helloworld}"
LOG="${3:-info}"
SMP="${4:-1}"

echo "=========================================="
echo "构建 ArceOS"
echo "=========================================="
echo "架构: $ARCH"
echo "应用: $APP"
echo "日志级别: $LOG"
echo "CPU 核心数: $SMP"
echo ""

# 检查工具链
case "$ARCH" in
    loongarch64)
        if [ ! -d "$LOONGARCH64_TOOLCHAIN" ]; then
            echo "错误: loongarch64 工具链不存在"
            exit 1
        fi
        ;;
    x86_64)
        if [ ! -d "$X86_64_TOOLCHAIN" ]; then
            echo "错误: x86_64 工具链不存在"
            exit 1
        fi
        ;;
    aarch64)
        if [ ! -d "$AARCH64_TOOLCHAIN" ]; then
            echo "错误: aarch64 工具链不存在"
            exit 1
        fi
        ;;
    riscv64)
        if [ ! -d "$RISCV64_TOOLCHAIN" ]; then
            echo "错误: riscv64 工具链不存在"
            exit 1
        fi
        ;;
    *)
        echo "错误: 不支持的架构: $ARCH"
        echo "支持的架构: loongarch64, x86_64, aarch64, riscv64"
        exit 1
        ;;
esac

# 构建 ArceOS
cd "$(dirname "${BASH_SOURCE[0]}")"
make A="$APP" ARCH="$ARCH" LOG="$LOG" SMP="$SMP" "$@"
EOF

chmod +x "$BUILD_SCRIPT"
log_info "✓ 已创建构建脚本: $BUILD_SCRIPT"

# 7. 创建运行脚本
log_check "创建运行脚本..."
RUN_SCRIPT="${ARCEOS_DIR}/run-with-musl.sh"

cat > "$RUN_SCRIPT" << 'EOF'
#!/bin/bash
# 使用 musl 工具链运行 ArceOS

# 加载工具链配置
source "$(dirname "${BASH_SOURCE[0]}")/setup-musl-toolchain.sh"

# 默认参数
ARCH="${1:-x86_64}"
APP="${2:-examples/helloworld}"
LOG="${3:-info}"
SMP="${4:-1}"

echo "=========================================="
echo "运行 ArceOS"
echo "=========================================="
echo "架构: $ARCH"
echo "应用: $APP"
echo "日志级别: $LOG"
echo "CPU 核心数: $SMP"
echo ""

# 运行 ArceOS
cd "$(dirname "${BASH_SOURCE[0]}")"
make A="$APP" ARCH="$ARCH" LOG="$LOG" SMP="$SMP" run "$@"
EOF

chmod +x "$RUN_SCRIPT"
log_info "✓ 已创建运行脚本: $RUN_SCRIPT"

# 总结
echo ""
echo "=========================================="
log_info "配置完成！"
echo "=========================================="
echo ""
log_info "已创建以下脚本："
echo "  1. $CONFIG_SCRIPT  - 配置工具链环境变量"
echo "  2. $BUILD_SCRIPT    - 构建 ArceOS"
echo "  3. $RUN_SCRIPT      - 运行 ArceOS"
echo ""
log_info "使用方法："
echo ""
echo "1. 配置工具链环境："
echo "   cd $ARCEOS_DIR"
echo "   source setup-musl-toolchain.sh"
echo ""
echo "2. 构建 ArceOS："
echo "   ./build-with-musl.sh <架构> <应用路径> <日志级别> <CPU核心数>"
echo "   例如:"
echo "   ./build-with-musl.sh x86_64 examples/helloworld info 1"
echo "   ./build-with-musl.sh aarch64 examples/httpserver info 4"
echo ""
echo "3. 运行 ArceOS："
echo "   ./run-with-musl.sh <架构> <应用路径> <日志级别> <CPU核心数>"
echo "   例如:"
echo "   ./run-with-musl.sh x86_64 examples/helloworld info 1"
echo "   ./run-with-musl.sh aarch64 examples/httpserver info 4 NET=y"
echo ""
log_info "更多信息请参考 ArceOS 文档："
echo "  https://github.com/arceos-org/arceos"
