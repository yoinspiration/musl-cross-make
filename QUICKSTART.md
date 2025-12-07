# 快速开始指南

## 在 macOS 上构建多架构 musl 工具链

### 1. 安装依赖

```bash
# 安装 Homebrew（如果还没有）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装必要的工具
brew install wget make
```

### 2. 构建所有架构

```bash
# 构建所有四个架构（loongarch64, x86_64, aarch64, riscv64）
./build-all.sh
```

这将依次编译：
- `loongarch64-linux-musl` - 龙芯架构
- `x86_64-linux-musl` - x86 64位
- `aarch64-linux-musl` - ARM 64位  
- `riscv64-linux-musl` - RISC-V 64位

每个架构的工具链将安装到 `output-<arch>` 目录。

### 3. 只构建特定架构

```bash
# 只构建 loongarch64
./build-all.sh --arch loongarch64-linux-musl
```

### 4. 测试工具链

```bash
# 测试所有已构建的工具链
./test-toolchain.sh
```

### 5. 使用工具链

```bash
# 设置环境变量（以 loongarch64 为例）
export PATH=$(pwd)/output-loongarch64-linux-musl/bin:$PATH

# 编译一个简单的 C 程序
cat > hello.c <<'EOF'
#include <stdio.h>
int main() {
    printf("Hello, musl!\n");
    return 0;
}
EOF

loongarch64-linux-musl-gcc -static -o hello hello.c

# 查看生成的二进制文件信息
file hello
```

## 构建时间估算

在典型的 macOS 系统上（M1/M2 Mac）：
- 单个架构：20-60 分钟
- 所有四个架构：2-4 小时

## 常见问题

### Q: 构建失败怎么办？
A: 检查错误日志，确保：
- 有足够的磁盘空间（至少 10GB）
- 网络连接正常（需要下载源码）
- 所有依赖已安装

### Q: macOS 上出现 zlib/fdopen 错误？
A: 这是已知的 macOS 兼容性问题。构建脚本已自动处理，会禁用 binutils 的 zlib 支持。如果仍有问题，可以手动在 `config.mak` 中添加：
```makefile
BINUTILS_CONFIG += --without-zlib
```

### Q: 可以在 Linux 上构建吗？
A: 可以，但脚本主要针对 macOS 优化。在 Linux 上可能需要调整 SHA1 命令。

### Q: 如何清理构建？
A: 使用 `make clean` 清理单个架构，或删除 `build/` 和 `output-*/` 目录。

## 下一步

查看 [README.BUILD.md](README.BUILD.md) 了解更详细的配置和高级用法。

