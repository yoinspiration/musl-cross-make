#!/bin/bash

# 检查 LoongArch 工具链构建状态

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

ARCH="loongarch64-linux-musl"
OUTPUT_DIR="output-${ARCH}"
BUILD_DIR="build/local/${ARCH}"

echo "=========================================="
log_info "检查 LoongArch 工具链构建状态"
echo "=========================================="
echo ""

# 1. 检查输出目录
log_check "1. 检查最终输出目录..."
if [ -d "$OUTPUT_DIR" ]; then
    log_info "✓ 输出目录存在: $OUTPUT_DIR"
    
    # 检查关键工具
    BIN_DIR="${OUTPUT_DIR}/bin"
    if [ -d "$BIN_DIR" ]; then
        GCC="${BIN_DIR}/${ARCH}-gcc"
        GXX="${BIN_DIR}/${ARCH}-g++"
        
        if [ -f "$GCC" ]; then
            log_info "✓ 找到 gcc: $GCC"
            if "$GCC" --version >/dev/null 2>&1; then
                log_info "✓ gcc 可以正常运行"
                "$GCC" --version | head -1
            else
                log_warn "✗ gcc 无法运行"
            fi
        else
            log_warn "✗ 找不到 gcc"
        fi
        
        if [ -f "$GXX" ]; then
            log_info "✓ 找到 g++: $GXX"
        else
            log_warn "✗ 找不到 g++"
        fi
        
        # 统计工具数量
        TOOL_COUNT=$(ls -1 "$BIN_DIR" 2>/dev/null | wc -l | tr -d ' ')
        log_info "工具链包含 $TOOL_COUNT 个工具"
    else
        log_warn "✗ bin 目录不存在"
    fi
    
    echo ""
    log_info "结论: LoongArch 工具链已成功构建！"
    exit 0
else
    log_warn "✗ 输出目录不存在: $OUTPUT_DIR"
fi
echo ""

# 2. 检查构建目录
log_check "2. 检查构建中间目录..."
if [ -d "$BUILD_DIR" ]; then
    log_info "✓ 构建目录存在: $BUILD_DIR"
    
    # 检查各个组件的构建状态
    if [ -d "${BUILD_DIR}/obj_binutils" ]; then
        log_info "✓ binutils 构建目录存在"
        BINUTILS_OBJ_COUNT=$(find "${BUILD_DIR}/obj_binutils" -name "*.o" 2>/dev/null | wc -l | tr -d ' ')
        log_info "  - 找到 $BINUTILS_OBJ_COUNT 个目标文件"
    else
        log_warn "✗ binutils 构建目录不存在"
    fi
    
    if [ -d "${BUILD_DIR}/obj_gcc" ]; then
        log_info "✓ gcc 构建目录存在"
        
        # 检查关键文件
        if [ -f "${BUILD_DIR}/obj_gcc/gcc/gcc-cross" ]; then
            log_info "✓ gcc-cross 已构建"
        else
            log_warn "✗ gcc-cross 未构建"
        fi
        
        if [ -f "${BUILD_DIR}/obj_gcc/xgcc" ]; then
            log_info "✓ xgcc 已构建"
        else
            log_warn "✗ xgcc 未构建"
        fi
        
        GCC_OBJ_COUNT=$(find "${BUILD_DIR}/obj_gcc" -name "*.o" 2>/dev/null | wc -l | tr -d ' ')
        log_info "  - 找到 $GCC_OBJ_COUNT 个目标文件"
    else
        log_warn "✗ gcc 构建目录不存在"
    fi
    
    if [ -d "${BUILD_DIR}/obj_musl" ]; then
        log_info "✓ musl 构建目录存在"
    else
        log_warn "✗ musl 构建目录不存在"
    fi
    
    # 检查最后修改时间
    if [ -d "${BUILD_DIR}/obj_gcc" ]; then
        LAST_MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "${BUILD_DIR}/obj_gcc" 2>/dev/null || stat -c "%y" "${BUILD_DIR}/obj_gcc" 2>/dev/null | cut -d' ' -f1-2)
        log_info "最后修改时间: $LAST_MODIFIED"
    fi
else
    log_warn "✗ 构建目录不存在: $BUILD_DIR"
    log_info "结论: LoongArch 尚未开始构建"
    exit 0
fi
echo ""

# 3. 检查配置文件
log_check "3. 检查配置文件..."
if [ -f "config.mak" ]; then
    TARGET=$(grep "^TARGET" config.mak | head -1 | awk '{print $3}')
    if [ "$TARGET" = "$ARCH" ]; then
        log_info "✓ config.mak 配置正确: TARGET = $TARGET"
    else
        log_warn "✗ config.mak 配置不匹配: TARGET = $TARGET (期望: $ARCH)"
    fi
else
    log_warn "✗ config.mak 不存在"
fi
echo ""

# 4. 检查是否有构建进程
log_check "4. 检查构建进程..."
BUILD_PROCESSES=$(ps aux | grep -E "(make|gcc|binutils)" | grep -v grep | wc -l | tr -d ' ')
if [ "$BUILD_PROCESSES" -gt 0 ]; then
    log_info "✓ 发现 $BUILD_PROCESSES 个相关进程（可能正在构建）"
else
    log_info "✗ 没有发现构建进程（构建可能已停止）"
fi
echo ""

# 5. 检查关键组件
log_check "5. 检查关键组件构建状态..."
# xgcc 可能在 obj_gcc 或 obj_gcc/gcc 目录
if [ -f "${BUILD_DIR}/obj_gcc/xgcc" ] || [ -f "${BUILD_DIR}/obj_gcc/gcc/xgcc" ]; then
    log_info "✓ xgcc 已构建"
    XGCC_PATH=$(find "${BUILD_DIR}/obj_gcc" -name "xgcc" -type f 2>/dev/null | head -1)
    if [ -n "$XGCC_PATH" ]; then
        log_info "  位置: $XGCC_PATH"
    fi
else
    log_warn "✗ xgcc 未构建"
fi

if [ -f "${BUILD_DIR}/obj_gcc/gcc/cc1" ]; then
    log_info "✓ cc1 (C 编译器) 已构建"
else
    log_warn "✗ cc1 未构建"
fi

if [ -f "${BUILD_DIR}/obj_gcc/gcc/cc1plus" ]; then
    log_info "✓ cc1plus (C++ 编译器) 已构建"
else
    log_warn "✗ cc1plus 未构建"
fi

if [ -d "${BUILD_DIR}/obj_sysroot" ]; then
    SYSROOT_FILES=$(find "${BUILD_DIR}/obj_sysroot" -type f 2>/dev/null | wc -l | tr -d ' ')
    log_info "✓ sysroot 目录存在，包含 $SYSROOT_FILES 个文件"
else
    log_warn "✗ sysroot 目录不存在"
fi
echo ""

# 总结
echo "=========================================="
if [ -d "$OUTPUT_DIR" ]; then
    log_info "总结: LoongArch 工具链已成功构建！"
    HAS_XGCC=true
    HAS_CC1=true
else
    # 检查是否有部分构建
    HAS_XGCC=$(find "${BUILD_DIR}/obj_gcc" -name "xgcc" -type f 2>/dev/null | head -1)
    HAS_CC1=$(find "${BUILD_DIR}/obj_gcc" -name "cc1" -type f 2>/dev/null | head -1)
    
    if [ -n "$HAS_XGCC" ] && [ -n "$HAS_CC1" ]; then
        log_warn "总结: LoongArch 工具链部分构建完成，可以继续构建"
        echo ""
        log_info "已构建关键组件（xgcc, cc1, cc1plus），建议继续构建而不是重新开始"
    else
        log_warn "总结: LoongArch 工具链尚未构建成功"
    fi
fi
echo "=========================================="
echo ""
log_info "建议操作:"
if [ -n "$HAS_XGCC" ] && [ -n "$HAS_CC1" ]; then
    echo "  1. 继续构建（推荐，会从上次停止的地方继续）:"
    echo "     ./resume-loongarch-build.sh"
    echo ""
    echo "  2. 或者使用构建脚本继续:"
    echo "     ./build-all.sh --arch $ARCH"
    echo ""
    echo "  3. 如果遇到问题，清理后重新构建:"
    echo "     rm -rf $BUILD_DIR config.mak"
    echo "     ./build-all.sh --arch $ARCH"
else
    echo "  1. 开始构建:"
    echo "     ./build-all.sh --arch $ARCH"
    echo ""
    echo "  2. 如果构建失败，查看构建日志:"
    echo "     find $BUILD_DIR -name '*.log' -type f"
    echo ""
    echo "  3. 清理后重新构建:"
    echo "     rm -rf $BUILD_DIR config.mak"
    echo "     ./build-all.sh --arch $ARCH"
fi
