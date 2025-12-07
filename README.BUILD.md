# 多架构 musl 交叉编译工具链构建指南

本仓库基于 [lyw19b/musl-cross-make](https://github.com/lyw19b/musl-cross-make) 支持 loongarch64 架构，并扩展支持在 macOS 上编译多个架构的 musl 工具链。

## 支持的架构

- `loongarch64-linux-musl` - 龙芯架构 64 位
- `x86_64-linux-musl` - x86 64 位
- `aarch64-linux-musl` - ARM 64 位
- `riscv64-linux-musl` - RISC-V 64 位

## 系统要求

### macOS

1. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

2. **Homebrew** (推荐)
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. **必要的工具**
   ```bash
   brew install wget make
   ```

4. **编译器**
   - macOS 自带的 clang 通常足够
   - 或者安装 GCC: `brew install gcc`

## 快速开始

### 1. 构建所有架构

```bash
./build-all.sh
```

这将依次编译所有四个架构的工具链。每个架构的工具链将安装到 `output-<arch>` 目录。

### 2. 构建单个架构

```bash
./build-all.sh --arch loongarch64-linux-musl
```

### 3. 清理后重新构建

```bash
./build-all.sh --clean
```

## 构建过程说明

构建过程包括以下步骤：

1. **下载源码**: 自动下载 GCC、binutils、musl、Linux 内核头文件等
2. **应用补丁**: 应用 musl 支持补丁
3. **配置编译**: 为每个架构配置交叉编译工具链
4. **编译工具链**: 编译完整的交叉编译工具链
5. **安装工具链**: 安装到 `output-<arch>` 目录

### 构建时间

在 macOS 上，每个架构的完整构建通常需要：
- **loongarch64**: 30-60 分钟
- **x86_64**: 20-40 分钟
- **aarch64**: 25-50 分钟
- **riscv64**: 30-60 分钟

总构建时间取决于 CPU 核心数和系统性能。

## 测试工具链

构建完成后，可以使用测试脚本验证工具链：

```bash
./test-toolchain.sh
```

测试脚本会：
- 检查工具链是否存在
- 验证编译器可以运行
- 编译测试 C/C++ 程序
- 检查生成的二进制文件

## 使用工具链

### 基本使用

工具链安装后，可以直接使用：

```bash
# 使用 loongarch64 工具链
export PATH=$(pwd)/output-loongarch64-linux-musl/bin:$PATH

# 编译 C 程序
loongarch64-linux-musl-gcc -static -o hello hello.c

# 编译 C++ 程序
loongarch64-linux-musl-g++ -static -o hello hello.cpp
```

### 在项目中使用

```bash
# 设置环境变量
export CC=loongarch64-linux-musl-gcc
export CXX=loongarch64-linux-musl-g++
export AR=loongarch64-linux-musl-ar
export STRIP=loongarch64-linux-musl-strip

# 编译项目
make
```

## 目录结构

```
musl-cross-make/
├── build-all.sh          # 多架构构建脚本
├── test-toolchain.sh     # 工具链测试脚本
├── config.mak.loongarch64 # loongarch64 专用配置
├── output-loongarch64-linux-musl/  # loongarch64 工具链
├── output-x86_64-linux-musl/       # x86_64 工具链
├── output-aarch64-linux-musl/      # aarch64 工具链
└── output-riscv64-linux-musl/      # riscv64 工具链
```

## 配置说明

### 默认配置

- **GCC 版本**: 13.2.0
- **Linux 内核头文件**: 6.7
- **支持语言**: C, C++
- **输出目录**: `output-<arch>`

### 自定义配置

可以编辑 `config.mak` 或创建架构特定的配置文件：

```makefile
TARGET = loongarch64-linux-musl
GCC_VER = 13.2.0
LINUX_VER = 6.7
GCC_CONFIG += --enable-languages=c,c++
```

## 故障排除

### 1. 下载失败

如果源码下载失败，可以：
- 检查网络连接
- 使用代理: `export http_proxy=...`
- 手动下载源码到 `sources/` 目录

### 2. 编译错误

- 确保有足够的磁盘空间（至少 10GB）
- 检查系统依赖是否完整
- 查看构建日志中的错误信息

### 3. macOS 特定问题

- **SHA1 校验**: 脚本会自动使用 `shasum` 替代 `sha1sum`
- **zlib 冲突**: 在 macOS 上，binutils 的 zlib 会与系统头文件冲突。脚本会自动添加 `--without-zlib` 选项来解决此问题
- **权限问题**: 确保有写入权限
- **下载工具**: 如果没有 `wget`，脚本会自动使用 `curl`

## 参考资源

- [musl 官方文档](https://musl.libc.org/)
- [原仓库 README](README.md)
- [LoongArch 构建说明](README.LoongArch.md)

## 许可证

本构建系统使用 MIT 许可证。编译出的工具链遵循各自上游项目的许可证。

