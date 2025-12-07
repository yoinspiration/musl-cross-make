#!/bin/bash

# 交互式构建脚本 - 逐个选择架构进行构建

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_menu() {
    echo -e "${CYAN}$1${NC}"
}

# 架构列表
ARCHITECTURES=(
    "loongarch64-linux-musl"
    "x86_64-linux-musl"
    "aarch64-linux-musl"
    "riscv64-linux-musl"
)

# 检查已构建的架构
check_built() {
    local arch=$1
    if [ -d "output-${arch}" ]; then
        return 0
    else
        return 1
    fi
}

# 显示菜单
show_menu() {
    clear
    echo "=========================================="
    log_menu "  多架构 musl 工具链构建菜单"
    echo "=========================================="
    echo ""
    
    for i in "${!ARCHITECTURES[@]}"; do
        local arch="${ARCHITECTURES[$i]}"
        local num=$((i+1))
        local status=""
        
        if check_built "$arch"; then
            status="${GREEN}[已构建]${NC}"
        else
            status="${YELLOW}[未构建]${NC}"
        fi
        
        echo -e "  ${CYAN}$num${NC}. $arch $status"
    done
    
    echo ""
    echo -e "  ${CYAN}5${NC}. 构建所有未构建的架构"
    echo -e "  ${CYAN}6${NC}. 查看已构建的架构"
    echo -e "  ${CYAN}7${NC}. 测试已构建的工具链"
    echo -e "  ${CYAN}0${NC}. 退出"
    echo ""
    echo -n "请选择 (0-7): "
}

# 构建单个架构
build_arch() {
    local arch=$1
    echo ""
    log_info "开始构建: $arch"
    echo "预计时间: 30-60 分钟"
    echo ""
    
    if ./build-all.sh --arch "$arch"; then
        echo ""
        log_info "$arch 构建成功！"
        echo ""
        read -p "按 Enter 继续..."
        return 0
    else
        echo ""
        log_error "$arch 构建失败"
        echo ""
        read -p "按 Enter 继续..."
        return 1
    fi
}

# 构建所有未构建的架构
build_all_remaining() {
    local remaining=()
    
    for arch in "${ARCHITECTURES[@]}"; do
        if ! check_built "$arch"; then
            remaining+=("$arch")
        fi
    done
    
    if [ ${#remaining[@]} -eq 0 ]; then
        log_info "所有架构都已构建完成！"
        read -p "按 Enter 继续..."
        return
    fi
    
    echo ""
    log_info "将构建以下架构: ${remaining[*]}"
    echo ""
    read -p "确认继续? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        for arch in "${remaining[@]}"; do
            build_arch "$arch"
        done
    fi
}

# 查看已构建的架构
show_built() {
    echo ""
    log_info "已构建的架构:"
    echo ""
    
    local has_built=false
    for arch in "${ARCHITECTURES[@]}"; do
        if check_built "$arch"; then
            echo -e "  ${GREEN}✓${NC} $arch -> output-${arch}"
            has_built=true
        fi
    done
    
    if [ "$has_built" = false ]; then
        log_warn "还没有构建任何架构"
    fi
    
    echo ""
    read -p "按 Enter 继续..."
}

# 测试工具链
test_toolchains() {
    echo ""
    if [ -f "./test-toolchain.sh" ]; then
        ./test-toolchain.sh
    else
        log_error "测试脚本不存在: test-toolchain.sh"
    fi
    echo ""
    read -p "按 Enter 继续..."
}

# 主循环
main() {
    cd "$(dirname "$0")"
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                build_arch "${ARCHITECTURES[0]}"
                ;;
            2)
                build_arch "${ARCHITECTURES[1]}"
                ;;
            3)
                build_arch "${ARCHITECTURES[2]}"
                ;;
            4)
                build_arch "${ARCHITECTURES[3]}"
                ;;
            5)
                build_all_remaining
                ;;
            6)
                show_built
                ;;
            7)
                test_toolchains
                ;;
            0)
                echo ""
                log_info "退出"
                exit 0
                ;;
            *)
                log_error "无效选择: $choice"
                sleep 1
                ;;
        esac
    done
}

main

