# macOS 构建问题修复

## 问题描述

在 macOS 上构建 musl-cross-make 时，遇到以下错误：

```
error: expected ')'
../../src_binutils/zlib/zutil.h:147:33: note: expanded from macro 'fdopen'
  147 | #        define fdopen(fd,mode) NULL /* No fdopen() */
```

这是因为 binutils 的 zlib 库中定义的 `fdopen` 宏与 macOS SDK 的系统头文件冲突。

## 解决方案

### 1. 禁用 binutils 的 zlib 支持

在 `config.mak` 中添加：
```makefile
BINUTILS_CONFIG += --without-zlib
```

### 2. 修复 zlib 源码

即使配置了 `--without-zlib`，binutils 仍然会编译 zlib 目录中的某些文件。因此，需要在编译前修复源码：

修改 `binutils-2.44/zlib/zutil.h` 文件，将：
```c
#        define fdopen(fd,mode) NULL /* No fdopen() */
```

改为：
```c
#        ifdef __APPLE__
#          undef fdopen
#        else
#          define fdopen(fd,mode) NULL /* No fdopen() */
#        endif
```

## 自动修复

`build-all.sh` 脚本已自动处理以上两个修复：

1. 自动在配置文件中添加 `BINUTILS_CONFIG += --without-zlib`
2. 在编译前自动修复 `zutil.h` 文件

## 使用方法

直接运行构建脚本即可，无需手动干预：

```bash
./build-all.sh
```

脚本会自动检测 macOS 环境并应用所有必要的修复。

