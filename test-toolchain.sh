#!/bin/bash

# 测试编译出的 musl 交叉编译工具链
# 在 macOS 上测试各个架构的工具链

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 测试单个架构的工具链
test_arch() {
    local arch=$1
    local toolchain_dir="output-${arch}"
    
    if [ ! -d "$toolchain_dir" ]; then
        log_error "工具链目录不存在: $toolchain_dir"
        return 1
    fi
    
    log_test "测试架构: $arch"
    
    local bin_dir="${toolchain_dir}/bin"
    local gcc="${bin_dir}/${arch}-gcc"
    local gxx="${bin_dir}/${arch}-g++"
    local strip="${bin_dir}/${arch}-strip"
    
    # 检查工具是否存在
    if [ ! -f "$gcc" ]; then
        log_error "找不到 gcc: $gcc"
        return 1
    fi
    
    log_info "找到工具链: $gcc"
    
    # 检查版本
    log_test "检查编译器版本..."
    if "$gcc" --version >/dev/null 2>&1; then
        log_success "编译器可以运行"
        "$gcc" --version | head -1
    else
        log_error "编译器无法运行"
        return 1
    fi
    
    # 创建测试程序
    local test_dir="/tmp/musl-test-${arch}"
    mkdir -p "$test_dir"
    
    cat > "${test_dir}/hello.c" <<'EOF'
#include <stdio.h>
#include <unistd.h>

int main() {
    printf("Hello from musl cross-compiler!\n");
    printf("Architecture: %s\n", 
#ifdef __loongarch64
        "loongarch64"
#elif defined(__x86_64__)
        "x86_64"
#elif defined(__aarch64__)
        "aarch64"
#elif defined(__riscv)
        "riscv64"
#else
        "unknown"
#endif
    );
    return 0;
}
EOF
    
    cat > "${test_dir}/hello.cpp" <<'EOF'
#include <iostream>
#include <cstdio>

int main() {
    std::cout << "Hello from C++ musl cross-compiler!" << std::endl;
    printf("C++ version: %ld\n", __cplusplus);
    return 0;
}
EOF
    
    # 测试 C 编译
    log_test "测试 C 编译..."
    if "$gcc" -static -o "${test_dir}/hello-c" "${test_dir}/hello.c" 2>&1; then
        log_success "C 程序编译成功"
        
        # 检查文件类型
        if command -v file >/dev/null 2>&1; then
            log_info "二进制文件信息:"
            file "${test_dir}/hello-c"
        fi
        
        # 检查文件大小
        local size=$(stat -f%z "${test_dir}/hello-c" 2>/dev/null || stat -c%s "${test_dir}/hello-c" 2>/dev/null || echo "unknown")
        log_info "二进制文件大小: $size 字节"
    else
        log_error "C 程序编译失败"
        return 1
    fi
    
    # 测试 C++ 编译
    if [ -f "$gxx" ]; then
        log_test "测试 C++ 编译..."
        if "$gxx" -static -o "${test_dir}/hello-cpp" "${test_dir}/hello.cpp" 2>&1; then
            log_success "C++ 程序编译成功"
        else
            log_error "C++ 程序编译失败"
        fi
    fi
    
    # 清理
    rm -rf "$test_dir"
    
    log_success "$arch 工具链测试通过"
    echo ""
}

# 主函数
main() {
    log_info "开始测试 musl 交叉编译工具链"
    echo ""
    
    local archs=(
        "loongarch64-linux-musl"
        "x86_64-linux-musl"
        "aarch64-linux-musl"
        "riscv64-linux-musl"
    )
    
    local tested=0
    local passed=0
    local failed=0
    
    for arch in "${archs[@]}"; do
        if [ -d "output-${arch}" ]; then
            tested=$((tested + 1))
            if test_arch "$arch"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi
        else
            log_info "跳过 $arch (工具链不存在)"
        fi
    done
    
    echo "=========================================="
    log_info "测试完成"
    echo "=========================================="
    log_info "总计: $tested 个工具链"
    log_success "通过: $passed"
    if [ $failed -gt 0 ]; then
        log_error "失败: $failed"
    fi
}

main

