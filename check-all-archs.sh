#!/bin/bash

# 检查所有架构的构建状态

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_fail() {
    echo -e "${RED}[✗]${NC} $1"
}

# 架构列表
ARCHITECTURES=(
    "loongarch64-linux-musl"
    "x86_64-linux-musl"
    "aarch64-linux-musl"
    "riscv64-linux-musl"
)

# 检查单个架构
check_arch() {
    local arch=$1
    local output_dir="output-${arch}"
    local bin_dir="${output_dir}/bin"
    local gcc="${bin_dir}/${arch}-gcc"
    local gxx="${bin_dir}/${arch}-g++"
    
    echo ""
    echo "=========================================="
    log_check "检查架构: $arch"
    echo "=========================================="
    
    local status="success"
    local issues=()
    
    # 1. 检查输出目录
    if [ -d "$output_dir" ]; then
        log_success "输出目录存在: $output_dir"
    else
        log_fail "输出目录不存在: $output_dir"
        status="failed"
        issues+=("输出目录不存在")
        echo ""
        return 1
    fi
    
    # 2. 检查 bin 目录
    if [ -d "$bin_dir" ]; then
        log_success "bin 目录存在"
        local tool_count=$(ls -1 "$bin_dir" 2>/dev/null | wc -l | tr -d ' ')
        log_info "工具数量: $tool_count"
    else
        log_fail "bin 目录不存在"
        status="failed"
        issues+=("bin 目录不存在")
    fi
    
    # 3. 检查 gcc
    if [ -f "$gcc" ]; then
        log_success "gcc 存在: $gcc"
        
        # 检查 gcc 版本
        if "$gcc" --version >/dev/null 2>&1; then
            log_success "gcc 可以运行"
            local version=$("$gcc" --version 2>/dev/null | head -1)
            log_info "版本: $version"
        else
            log_fail "gcc 无法运行"
            status="failed"
            issues+=("gcc 无法运行")
        fi
    else
        log_fail "gcc 不存在: $gcc"
        status="failed"
        issues+=("gcc 不存在")
    fi
    
    # 4. 检查 g++
    if [ -f "$gxx" ]; then
        log_success "g++ 存在: $gxx"
        
        if "$gxx" --version >/dev/null 2>&1; then
            log_success "g++ 可以运行"
        else
            log_warn "g++ 无法运行（可能不影响使用）"
        fi
    else
        log_warn "g++ 不存在（可能未启用 C++）"
    fi
    
    # 5. 检查其他关键工具
    local tools=("${arch}-ar" "${arch}-ld" "${arch}-strip" "${arch}-objdump")
    local found_tools=0
    for tool in "${tools[@]}"; do
        if [ -f "${bin_dir}/${tool}" ]; then
            found_tools=$((found_tools + 1))
        fi
    done
    log_info "关键工具: $found_tools/${#tools[@]} 个存在"
    
    # 6. 检查构建目录（如果存在）
    local build_dir="build/local/${arch}"
    if [ -d "$build_dir" ]; then
        log_info "构建目录存在（可能正在构建或构建未完成）"
    fi
    
    # 总结
    echo ""
    if [ "$status" = "success" ]; then
        log_success "$arch 构建成功！"
        return 0
    else
        log_fail "$arch 构建未完成"
        if [ ${#issues[@]} -gt 0 ]; then
            log_warn "问题:"
            for issue in "${issues[@]}"; do
                echo "  - $issue"
            done
        fi
        return 1
    fi
}

# 主函数
main() {
    echo "=========================================="
    log_info "检查所有架构的构建状态"
    echo "=========================================="
    echo ""
    log_info "要检查的架构: ${ARCHITECTURES[*]}"
    echo ""
    
    local total=0
    local success=0
    local failed=0
    local success_archs=()
    local failed_archs=()
    
    for arch in "${ARCHITECTURES[@]}"; do
        total=$((total + 1))
        if check_arch "$arch"; then
            success=$((success + 1))
            success_archs+=("$arch")
        else
            failed=$((failed + 1))
            failed_archs+=("$arch")
        fi
    done
    
    # 最终总结
    echo ""
    echo "=========================================="
    log_info "构建状态总结"
    echo "=========================================="
    echo ""
    log_info "总计: $total 个架构"
    log_success "成功: $success 个"
    if [ $failed -gt 0 ]; then
        log_fail "失败: $failed 个"
    fi
    echo ""
    
    if [ ${#success_archs[@]} -gt 0 ]; then
        log_info "已成功构建的架构:"
        for arch in "${success_archs[@]}"; do
            echo "  ✓ $arch -> output-${arch}"
        done
        echo ""
    fi
    
    if [ ${#failed_archs[@]} -gt 0 ]; then
        log_warn "未成功构建的架构:"
        for arch in "${failed_archs[@]}"; do
            echo "  ✗ $arch"
        done
        echo ""
        log_info "建议操作:"
        for arch in "${failed_archs[@]}"; do
            echo "  ./build-all.sh --arch $arch"
        done
    fi
    
    echo ""
    if [ $failed -eq 0 ]; then
        log_success "所有架构都已成功构建！"
        exit 0
    else
        log_warn "部分架构构建未完成"
        exit 1
    fi
}

main
