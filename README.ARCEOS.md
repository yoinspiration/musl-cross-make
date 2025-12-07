# 使用 musl 工具链构建和运行 ArceOS

本指南说明如何使用我们构建的 musl 工具链来构建和运行 ArceOS。

## 前置要求

### 1. 已构建的 musl 工具链

确保所有架构的工具链都已构建完成：

```bash
./check-all-archs.sh
```

应该看到所有四个架构都已成功构建：
- `loongarch64-linux-musl`
- `x86_64-linux-musl`
- `aarch64-linux-musl`
- `riscv64-linux-musl`

### 2. Rust 工具链

安装 Rust 和必要的工具：

```bash
# 安装 Rust（如果还没有）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 安装 ArceOS 需要的 Rust 工具
cargo install cargo-binutils axconfig-gen cargo-axplat
```

### 3. QEMU

在 macOS 上安装 QEMU：

```bash
brew install qemu
```

确保 QEMU 版本 >= 8.2.0。

### 4. LLVM/Clang（用于构建 C 应用）

在 macOS 上，通常已经安装了 Xcode Command Line Tools，其中包含 clang。

## 快速开始

### 步骤 1: 配置 ArceOS

运行配置脚本：

```bash
./setup-arceos.sh
```

这个脚本会：
- 检查所有工具链是否存在
- 检查 ArceOS 仓库（如果不存在会提示克隆）
- 检查并安装必要的 Rust 工具
- 检查 QEMU
- 创建配置和构建脚本

### 步骤 2: 克隆 ArceOS（如果还没有）

```bash
cd ..
git clone https://github.com/arceos-org/arceos.git
cd arceos
```

### 步骤 3: 使用工具链构建 ArceOS

进入 ArceOS 目录并加载工具链配置：

```bash
cd arceos
source setup-musl-toolchain.sh
```

然后使用构建脚本：

```bash
# 构建 x86_64 架构的 helloworld 示例
./build-with-musl.sh x86_64 examples/helloworld info 1

# 构建 aarch64 架构的 httpserver 示例
./build-with-musl.sh aarch64 examples/httpserver info 4
```

### 步骤 4: 运行 ArceOS

```bash
# 运行 x86_64 架构的 helloworld
./run-with-musl.sh x86_64 examples/helloworld info 1

# 运行 aarch64 架构的 httpserver（带网络支持）
./run-with-musl.sh aarch64 examples/httpserver info 4 NET=y
```

## 手动构建（不使用脚本）

如果你想手动构建，可以这样做：

### 1. 设置环境变量

```bash
# 在 ArceOS 目录中
source setup-musl-toolchain.sh
```

或者手动设置：

```bash
export PATH="$(pwd)/../musl-cross-make/output-x86_64-linux-musl/bin:$PATH"
export PATH="$(pwd)/../musl-cross-make/output-aarch64-linux-musl/bin:$PATH"
export PATH="$(pwd)/../musl-cross-make/output-riscv64-linux-musl/bin:$PATH"
export PATH="$(pwd)/../musl-cross-make/output-loongarch64-linux-musl/bin:$PATH"
```

### 2. 使用 ArceOS 的 Makefile

```bash
# 构建
make A=examples/helloworld ARCH=x86_64 LOG=info SMP=1

# 运行
make A=examples/helloworld ARCH=x86_64 LOG=info SMP=1 run

# 带网络支持运行
make A=examples/httpserver ARCH=aarch64 LOG=info SMP=4 run NET=y
```

## 支持的架构和示例

### x86_64

```bash
# 构建和运行 helloworld
./build-with-musl.sh x86_64 examples/helloworld info 1
./run-with-musl.sh x86_64 examples/helloworld info 1
```

### aarch64

```bash
# 构建和运行 httpserver（带网络）
./build-with-musl.sh aarch64 examples/httpserver info 4
./run-with-musl.sh aarch64 examples/httpserver info 4 NET=y
```

### riscv64

```bash
# 构建和运行 helloworld
./build-with-musl.sh riscv64 examples/helloworld info 1
./run-with-musl.sh riscv64 examples/helloworld info 1
```

### loongarch64

```bash
# 构建和运行 helloworld
./build-with-musl.sh loongarch64 examples/helloworld info 1
./run-with-musl.sh loongarch64 examples/helloworld info 1
```

## 常见问题

### 1. 工具链未找到

确保工具链已构建：

```bash
cd musl-cross-make
./check-all-archs.sh
```

如果缺少某个架构，运行：

```bash
./build-all.sh --arch <架构名>
```

### 2. QEMU 版本过低

确保 QEMU 版本 >= 8.2.0：

```bash
qemu-system-x86_64 --version
```

如果版本过低，更新 QEMU：

```bash
brew upgrade qemu
```

### 3. Rust 工具未安装

安装缺失的工具：

```bash
cargo install cargo-binutils axconfig-gen cargo-axplat
```

### 4. 构建失败

检查：
- 工具链是否正确配置（运行 `source setup-musl-toolchain.sh`）
- 架构名称是否正确（x86_64, aarch64, riscv64, loongarch64）
- 应用路径是否存在

## 更多信息

- ArceOS 官方文档: https://github.com/arceos-org/arceos
- ArceOS 示例: https://github.com/arceos-org/arceos/tree/main/examples
