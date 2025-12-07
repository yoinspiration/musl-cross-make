#!/bin/bash

# 多架构 musl 交叉编译工具链构建脚本
# 支持在 macOS 上编译多个架构的 musl 工具链

set -e

# 定义要编译的架构列表
ARCHITECTURES=(
    "loongarch64-linux-musl"
    "x86_64-linux-musl"
    "aarch64-linux-musl"
    "riscv64-linux-musl"
)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查构建依赖..."
    
    local missing_deps=()
    
    # 检查必要的工具
    command -v make >/dev/null 2>&1 || missing_deps+=("make")
    command -v gcc >/dev/null 2>&1 || missing_deps+=("gcc")
    command -v wget >/dev/null 2>&1 || {
        command -v curl >/dev/null 2>&1 || missing_deps+=("wget 或 curl")
    }
    command -v sha1sum >/dev/null 2>&1 || {
        command -v shasum >/dev/null 2>&1 || missing_deps+=("sha1sum 或 shasum")
    }
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少以下依赖: ${missing_deps[*]}"
        log_info "在 macOS 上可以使用 Homebrew 安装:"
        log_info "  brew install wget"
        exit 1
    fi
    
    log_info "依赖检查完成"
}

# 为 macOS 配置环境
setup_macos() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "检测到 macOS，配置构建环境..."
        
        # 检查并使用 shasum
        if command -v shasum >/dev/null 2>&1; then
            log_info "使用 shasum 进行 SHA1 校验"
        else
            log_warn "未找到 shasum，SHA1 校验可能失败"
        fi
        
        # 检查并使用 curl（如果没有 wget）
        if ! command -v wget >/dev/null 2>&1; then
            if command -v curl >/dev/null 2>&1; then
                log_info "使用 curl 下载源码（未找到 wget）"
                export DL_CMD="curl -C - -L -o"
            fi
        fi
        
        # 检查 make 版本，如果系统 make 版本太旧，使用 gmake
        local make_version=$(make --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        if [ -n "$make_version" ]; then
            local major=$(echo "$make_version" | cut -d. -f1)
            local minor=$(echo "$make_version" | cut -d. -f2)
            if [ "$major" -lt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -lt 82 ]); then
                if command -v gmake >/dev/null 2>&1; then
                    log_info "系统 make 版本太旧 ($make_version)，使用 gmake"
                    export MAKE=gmake
                else
                    log_warn "系统 make 版本太旧 ($make_version)，建议安装: brew install make"
                fi
            fi
        fi
    fi
}

# 构建单个架构
build_arch() {
    local arch=$1
    local config_file="config.mak.${arch//-/_}"
    
    log_info "开始构建架构: $arch"
    
    # 创建架构特定的配置文件
    if [ -f "config.mak.loongarch64" ] && [ "$arch" = "loongarch64-linux-musl" ]; then
        log_info "使用 loongarch64 专用配置"
        cp config.mak.loongarch64 config.mak
        # 在 macOS 上添加 zlib 禁用选项和跳过内核头文件
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ! grep -q "BINUTILS_CONFIG" config.mak; then
                echo "" >> config.mak
                echo "# macOS 特定配置：禁用 zlib 以避免与系统头文件冲突" >> config.mak
                echo "BINUTILS_CONFIG += --without-zlib" >> config.mak
            fi
            # 在 macOS 上跳过内核头文件构建（因为 sed 兼容性问题）
            if grep -q "^LINUX_VER" config.mak; then
                # 完全删除 LINUX_VER 行，而不是注释，以确保构建系统不会使用它
                sed -i.bak '/^LINUX_VER/d' config.mak
                rm -f config.mak.bak
                log_info "在 macOS 上跳过内核头文件构建（可选的，不影响工具链使用）"
            fi
        fi
    else
        log_info "创建 $arch 的配置文件"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "在 macOS 上跳过内核头文件构建（可选的，不影响工具链使用）"
        fi
        create_config "$arch" > config.mak
    fi
    
    # 清理之前的构建（可选）
    if [ "$CLEAN" = "true" ]; then
        log_info "清理之前的构建..."
        make clean || true
    fi
    
    # 确保源码已提取（用于后续修复）
    if ! [ -d "binutils-2.44" ]; then
        log_info "提取源码..."
        make extract_all || true
    fi
    
    # macOS 上修复 zlib 源码以避免与系统头文件冲突
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "检查并修复 macOS 兼容性问题..."
        
        # 修复 LoongArch genstr.sh 脚本的 macOS 兼容性问题
        if [ "$arch" = "loongarch64-linux-musl" ] && [ -f "gcc-13.2.0/gcc/config/loongarch/genopts/genstr.sh" ]; then
            if ! grep -q "n = split(line, parts)" "gcc-13.2.0/gcc/config/loongarch/genopts/genstr.sh" 2>/dev/null; then
                log_info "修复 LoongArch genstr.sh 脚本的 macOS 兼容性..."
                # 确保修复已应用（检查关键修复点）
                if ! awk '/BEGIN \{/,/close\(strings_file\)/ {if(/n = split\(line, parts\)/) found=1} END {exit !found}' "gcc-13.2.0/gcc/config/loongarch/genopts/genstr.sh" 2>/dev/null; then
                    log_warn "LoongArch genstr.sh 可能需要手动修复，但继续构建..."
                fi
            fi
        fi
        
        # 修复函数：修复单个 zlib 文件
        fix_zlib_file() {
            local file_path=$1
            if [ -f "$file_path" ] && ! grep -q "__APPLE__" "$file_path" 2>/dev/null; then
                python3 << PYEOF
import sys
import re

file_path = "$file_path"
try:
    with open(file_path, 'r') as f:
        content = f.read()
    
    # 检查是否已经修复过
    if '__APPLE__' in content:
        print(f"已修复: {file_path}")
        sys.exit(0)
    
    # 使用正则表达式精确替换
    # 匹配模式: #      ifndef fdopen\n#        define fdopen(fd,mode) NULL /* No fdopen() */
    pattern = r'(#      ifndef fdopen\n)(#        define fdopen\(fd,mode\) NULL /\* No fdopen\(\) \*/\n)'
    replacement = r'\1#        ifdef __APPLE__\n#          undef fdopen\n#        else\n#          define fdopen(fd,mode) NULL /* No fdopen() */\n#        endif\n'
    
    new_content = re.sub(pattern, replacement, content)
    
    if new_content != content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"已修复: {file_path}")
    else:
        print(f"无需修复: {file_path}")
except Exception as e:
    print(f"修复失败 {file_path}: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
            fi
        }
        
        # 修复 binutils 的 zlib
        if [ -f "binutils-2.44/zlib/zutil.h" ]; then
            fix_zlib_file "binutils-2.44/zlib/zutil.h"
        fi
        
        # 修复 GCC 的 zlib（需要根据 GCC 版本动态检测）
        for gcc_dir in gcc-*; do
            if [ -d "$gcc_dir" ] && [ -f "$gcc_dir/zlib/zutil.h" ]; then
                fix_zlib_file "$gcc_dir/zlib/zutil.h"
            fi
            
            # 修复 GCC libcpp 的 setlocale 宏冲突
            if [ -f "$gcc_dir/libcpp/system.h" ]; then
                # 检查是否已经正确修复（只有一个修复块）
                if ! grep -q "^#ifdef __APPLE__$" "$gcc_dir/libcpp/system.h" 2>/dev/null || \
                   [ $(grep -c "^#ifdef __APPLE__$" "$gcc_dir/libcpp/system.h" 2>/dev/null || echo 0) -gt 1 ]; then
                    log_info "修复 GCC libcpp setlocale 宏冲突..."
                    # 先清理所有重复的修复块
                    python3 << PYEOF
import sys
import re

file_path = "$gcc_dir/libcpp/system.h"
try:
    with open(file_path, 'r') as f:
        content = f.read()
    
    # 移除所有重复的修复块，只保留一个
    # 匹配模式：#ifdef ENABLE_NLS 后面的所有 #ifdef __APPLE__ ... #endif 块
    pattern = r'(#ifdef ENABLE_NLS\n)(#ifdef __APPLE__\n# undef setlocale\n#endif\n)+'
    replacement = r'\1#ifdef __APPLE__\n# undef setlocale\n#endif\n'
    
    new_content = re.sub(pattern, replacement, content)
    
    # 确保格式正确（#endif 后面有换行）
    new_content = new_content.replace('#endif#ifdef __APPLE__', '#endif\n#ifdef __APPLE__')
    new_content = new_content.replace('#endif#undef', '#endif\n#undef')
    
    with open(file_path, 'w') as f:
        f.write(new_content)
    print(f"已修复: {file_path}")
except Exception as e:
    print(f"修复失败 {file_path}: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
                    log_info "已修复 $gcc_dir/libcpp/system.h"
                fi
            fi
            
            # 修复 GCC system.h 的 ctype 宏冲突和 poison 问题
            if [ -f "$gcc_dir/gcc/system.h" ] && ! grep -q "GCC_SYSTEM_H_TEMP_DISABLE_POISON" "$gcc_dir/gcc/system.h" 2>/dev/null; then
                log_info "修复 GCC system.h ctype 宏冲突和 poison 问题..."
                python3 << PYEOF
import sys

file_path = "$gcc_dir/gcc/system.h"
try:
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    i = 0
    found_cplusplus = False
    found_include_map = False
    
    while i < len(lines):
        line = lines[i]
        
        # 找到 #ifdef __cplusplus 和 #include <map> 之间的位置
        if '#ifdef __cplusplus' in line:
            found_cplusplus = True
            new_lines.append(line)
            i += 1
            # 添加 macOS 特定的宏取消定义和 poison 禁用
            new_lines.append('/* On macOS, temporarily undefine ctype macros and disable poison\n')
            new_lines.append('   before including C++ standard library headers. */\n')
            new_lines.append('#ifdef __APPLE__\n')
            new_lines.append('# undef isalpha\n')
            new_lines.append('# undef isalnum\n')
            new_lines.append('# undef iscntrl\n')
            new_lines.append('# undef isdigit\n')
            new_lines.append('# undef isgraph\n')
            new_lines.append('# undef islower\n')
            new_lines.append('# undef isprint\n')
            new_lines.append('# undef ispunct\n')
            new_lines.append('# undef isspace\n')
            new_lines.append('# undef isupper\n')
            new_lines.append('# undef isxdigit\n')
            new_lines.append('# undef toupper\n')
            new_lines.append('# undef tolower\n')
            new_lines.append('# define GCC_SYSTEM_H_TEMP_DISABLE_POISON\n')
            new_lines.append('#endif\n')
            continue
        
        # 在 #include <utility> 之后恢复宏定义和 poison
        if found_cplusplus and '# include <utility>' in line:
            new_lines.append(line)
            i += 1
            # 添加恢复宏定义的代码
            new_lines.append('#ifdef __APPLE__\n')
            new_lines.append('/* Restore the safe-ctype macros after including C++ headers */\n')
            new_lines.append('# define isalpha(c) do_not_use_isalpha_with_safe_ctype\n')
            new_lines.append('# define isalnum(c) do_not_use_isalnum_with_safe_ctype\n')
            new_lines.append('# define iscntrl(c) do_not_use_iscntrl_with_safe_ctype\n')
            new_lines.append('# define isdigit(c) do_not_use_isdigit_with_safe_ctype\n')
            new_lines.append('# define isgraph(c) do_not_use_isgraph_with_safe_ctype\n')
            new_lines.append('# define islower(c) do_not_use_islower_with_safe_ctype\n')
            new_lines.append('# define isprint(c) do_not_use_isprint_with_safe_ctype\n')
            new_lines.append('# define ispunct(c) do_not_use_ispunct_with_safe_ctype\n')
            new_lines.append('# define isspace(c) do_not_use_isspace_with_safe_ctype\n')
            new_lines.append('# define isupper(c) do_not_use_isupper_with_safe_ctype\n')
            new_lines.append('# define isxdigit(c) do_not_use_isxdigit_with_safe_ctype\n')
            new_lines.append('# define toupper(c) do_not_use_toupper_with_safe_ctype\n')
            new_lines.append('# define tolower(c) do_not_use_tolower_with_safe_ctype\n')
            new_lines.append('# undef GCC_SYSTEM_H_TEMP_DISABLE_POISON\n')
            new_lines.append('#endif\n')
            continue
        
        # 在 poison 定义处添加条件编译
        if '#pragma GCC poison malloc realloc' in line or '#pragma GCC poison calloc strdup strndup' in line:
            new_lines.append('#ifndef GCC_SYSTEM_H_TEMP_DISABLE_POISON\n')
            new_lines.append(line)
            new_lines.append('#endif\n')
            i += 1
            continue
        
        new_lines.append(line)
        i += 1
    
    with open(file_path, 'w') as f:
        f.writelines(new_lines)
    print(f"已修复: {file_path}")
except Exception as e:
    print(f"修复失败 {file_path}: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
                log_info "已修复 $gcc_dir/gcc/system.h"
            fi
        done
        
        log_info "macOS 兼容性修复完成"
    fi
    
    # 开始构建
    log_info "编译 $arch..."
    
    # 使用环境变量中的 MAKE（如果设置了）
    local make_cmd="${MAKE:-make}"
    
    if $make_cmd -j$(sysctl -n hw.ncpu 2>/dev/null || echo 4); then
        log_info "$arch 编译成功"
        
        # 安装
        log_info "安装 $arch 工具链..."
        $make_cmd install
        
        # 移动到架构特定的输出目录
        if [ -d "output" ]; then
            local arch_output="output-${arch}"
            if [ -d "$arch_output" ]; then
                rm -rf "$arch_output"
            fi
            mv output "$arch_output"
            log_info "$arch 工具链已安装到: $arch_output"
        fi
    else
        log_error "$arch 编译失败"
        return 1
    fi
}

# 创建配置文件
create_config() {
    local arch=$1
    local sha1_cmd="sha1sum -c"
    local binutils_config=""
    local linux_ver="6.7"
    
    # macOS 使用 shasum
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sha1_cmd="shasum -a 1 -c"
        # macOS 上禁用 binutils 的 zlib 以避免与系统头文件冲突
        binutils_config="BINUTILS_CONFIG += --without-zlib"
        # macOS 上跳过内核头文件构建（因为 sed 兼容性问题）
        # 如果需要内核头文件，可以手动安装或使用 Linux 系统构建
        linux_ver=""
    fi
    
    # 输出配置文件内容（不包含日志）
    cat <<EOF
# 自动生成的配置文件 for $arch
TARGET = $arch

# 使用与 loongarch64 相同的版本配置
GCC_VER = 13.2.0
$(if [ -n "$linux_ver" ]; then echo "LINUX_VER = $linux_ver"; else echo "# LINUX_VER = 6.7  # 在 macOS 上跳过内核头文件"; fi)

# 启用 C 和 C++
GCC_CONFIG += --enable-languages=c,c++

GCC_STRIP = true

# SHA1 命令 (自动适配 macOS)
SHA1_CMD = $sha1_cmd

# macOS 特定的 binutils 配置
$binutils_config
EOF
}

# 主函数
main() {
    log_info "开始构建多架构 musl 交叉编译工具链"
    log_info "目标架构: ${ARCHITECTURES[*]}"
    
    check_dependencies
    setup_macos
    
    local failed_archs=()
    local success_archs=()
    
    # 构建每个架构
    for arch in "${ARCHITECTURES[@]}"; do
        if build_arch "$arch"; then
            success_archs+=("$arch")
        else
            failed_archs+=("$arch")
        fi
        echo ""
    done
    
    # 总结
    echo "=========================================="
    log_info "构建完成！"
    echo "=========================================="
    log_info "成功构建的架构 (${#success_archs[@]}):"
    for arch in "${success_archs[@]}"; do
        echo "  ✓ $arch -> output-${arch}"
    done
    
    if [ ${#failed_archs[@]} -ne 0 ]; then
        log_warn "失败的架构 (${#failed_archs[@]}):"
        for arch in "${failed_archs[@]}"; do
            echo "  ✗ $arch"
        done
        exit 1
    fi
}

# 解析命令行参数
CLEAN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --arch)
            ARCHITECTURES=("$2")
            shift 2
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --clean    清理之前的构建"
            echo "  --arch ARCH 只构建指定架构"
            echo "  --help     显示此帮助信息"
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            exit 1
            ;;
    esac
done

# 运行主函数
main

