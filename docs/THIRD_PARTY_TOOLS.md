# 内置第三方工具

灵犀右键只在系统公开能力不足以覆盖产品功能时随附独立命令行工具。构建时会将工具分别放入宿主应用与 Finder 扩展的 `Contents/Resources/Tools`；扩展内副本继承扩展沙盒权限，避免把用户文件路径转交给无授权的宿主进程。

## libwebp

- 版本：Google libwebp 1.6.0。
- 官方源码：`https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz`。
- 源码归档 SHA-256：`e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564`。
- `Sources/Tools/WebPEncoder.c` 使用系统 ImageIO 解码与处理方向，静态调用 libwebp 编码 RGBA 数据。
- `Scripts/build_webp_tool.sh` 分别以 macOS 13 为部署目标构建 arm64、x86_64，再合并为 `Resources/Tools/webp-encoder`。

官方预编译 WebP 1.6.0 工具最低要求 macOS 15，因此仓库不直接复制该二进制，而是从已校验源码构建兼容版本。

完整再生成命令：

```bash
./Scripts/build_webp_tool.sh
```

每次更新版本时必须同步更新 `THIRD_PARTY_NOTICES.md`、许可文本、固定下载摘要，并重新运行 `make test && make build`。
