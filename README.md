# 灵犀右键

一个原生 macOS Finder 扩展，为 Finder 右键菜单补充新建文件、复制/移动到常用目录、路径与文件信息、隐藏切换、图片转换和“用应用打开”等高频能力。

项目不依赖第三方库，也不复制“超级右键”的代码和素材。宿主应用使用 AppKit，右键菜单使用 Apple 官方 Finder Sync Extension。

## 当前功能

- 在 Finder 空白处新建 TXT、Markdown、JSON、Swift 文件或文件夹
- 将选中文件复制/移动到下载、文稿、图片等常用目录
- 复制名称、复制路径、计算 MD5/SHA-256
- 隐藏或取消隐藏文件
- 在终端、Visual Studio Code、GoLand 中打开目录
- 将图片转换为 PNG 或 JPEG
- 配置中心实时启停模板、目标目录和工具项
- 菜单栏入口、Finder 工具栏入口、扩展状态与系统管理入口

## 构建与安装

本机只需要 Command Line Tools，无需完整 Xcode：

```bash
make build
make test
make install
```

`make install` 会安装到 `/Applications/灵犀右键.app`（Finder Sync 扩展需要标准应用目录才能被系统稳定发现）。安装后在“系统设置 → 通用 → 登录项与扩展 → 文件提供程序/访达扩展”中启用“灵犀右键 Finder 扩展”。也可以在应用的“通用设置”页打开系统扩展管理界面。

若 Finder 没有立即刷新，可运行：

```bash
killall Finder
```

## 开发

- `Sources/Core`：宿主与扩展共享的数据模型、配置和文件操作
- `Sources/App`：配置中心和菜单栏应用
- `Sources/FinderExtension`：Finder Sync 菜单与动作
- `Resources`：应用/扩展 Info.plist
- `Scripts/build.sh`：无 Xcode 构建并签名 `.app`/`.appex`

默认配置保存在：

```text
~/Library/Containers/com.vibecoding.VibeRight.FinderExtension/Data/Library/Application Support/VibeRight/config.json
```

## 已知边界

Finder Sync 是 Apple 公共 API，但系统要求用户显式启用扩展。第一版没有实现永久删除、修改文件权限和批量解散目录等高风险操作；没有复刻原应用的付费、推广、翻译和第三方压缩软件入口。

当前无开发者证书的本地构建使用沙盒“主目录读写”临时例外，以便 Finder 扩展处理用户主目录内的文件。正式分发前应改为 Developer ID 签名，并通过安全作用域书签或用户明确授予的目录权限收窄访问范围。
