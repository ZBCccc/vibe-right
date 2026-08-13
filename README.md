# 灵犀右键

一个原生 macOS Finder 扩展，为 Finder 右键菜单补充新建文件、复制/移动到常用目录、路径与文件信息、隐藏切换、图片转换和“用应用打开”等高频能力。

项目不依赖第三方库，也不复制“超级右键”的代码和素材。宿主应用使用 AppKit，右键菜单使用 Apple 官方 Finder Sync Extension。

## 当前功能

- 在 Finder 空白处新建 TXT、RTF、XML、DOCX、XLSX、PPTX、WPS 文字/表格/演示、Ai、PSD、Markdown、JSON、Swift 文件或文件夹
- 导入任意现成文件作为自定义新建模板
- 使用原创内置图标或导入图片设置文件、文件夹图标，并可恢复默认
- 将选中文件复制/移动到预设目录或临时选择的自定义目录
- 独立维护常用目录，并可从 Finder 直接添加
- 复制名称、复制路径，计算 MD5/SHA-1/SHA-256/SHA-512
- AirDrop、解散文件夹、设置墙纸和补充所有者写权限
- 桌面快捷方式、带确认的彻底删除、ZIP/7z 压缩与解压
- 隐藏或取消隐藏已选/当前目录文件，切换扩展名显示
- 根据所选项目路径离线生成可扫描的 PNG 二维码
- 在任意支持 macOS 服务的应用中，对选中文本调用百度翻译、谷歌翻译或生成二维码
- 支持跟随系统，以及简体中文、繁體中文、English、日本語、한국어、Français、Español、Português、Deutsch
- 在系统终端、iTerm2 中按配置打开新窗口或新标签页，并支持 Warp
- 内置 VS Code、Cursor、Sublime、Obsidian、JetBrains 等 27 个应用入口
- 可从 `/Applications` 添加任意 macOS 应用作为“进入应用”动作
- 将图片转换为 PNG 或 JPEG
- 将图片转换为 WebP、HEIC、ICNS，生成 macOS/iOS 图标集
- 配置中心实时启停模板、目标目录和工具项；工具动作与应用入口可改名、排序
- 模板可重命名、排序并直接提升到 Finder 主菜单；传送目录和常用目录可重命名、排序
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
- `Resources`：应用/扩展 Info.plist 与独立生成的内置空白模板
- `Scripts/build.sh`：无 Xcode 构建并签名 `.app`/`.appex`

WPS 二进制模板的生成方式、校验摘要和隐私检查见 [`docs/BUILT_IN_TEMPLATES.md`](docs/BUILT_IN_TEMPLATES.md)。
多语言资源、运行时切换与完整性约束见 [`docs/LOCALIZATION.md`](docs/LOCALIZATION.md)。

默认配置保存在：

```text
~/Library/Containers/com.vibecoding.VibeRight.FinderExtension/Data/Library/Application Support/VibeRight/config.json
```

## 已知边界

Finder Sync 是 Apple 公共 API，但系统要求用户显式启用扩展。彻底删除默认要求二次确认，写权限操作只补充所有者写入位，解散目录包含名称冲突处理与失败回滚；没有复刻原应用的付费、推广和第三方软件入口。翻译动作会把用户选中的文本作为查询参数发送到所选翻译网站，二维码生成完全离线。

当前无开发者证书的本地构建使用沙盒“主目录读写”和 `/Volumes/` 临时例外，以便 Finder 扩展处理用户主目录及用户启用的外接卷。正式分发前应改为 Developer ID 签名，并通过安全作用域书签或用户明确授予的目录权限收窄访问范围。

## 许可证

本项目采用 [MIT License](LICENSE)。
