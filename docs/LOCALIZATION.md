# 多语言实现

灵犀右键支持跟随系统，以及简体中文、繁體中文、English、日本語、한국어、Français、Español、Português、Deutsch。语言选择保存在共享配置中，宿主应用与 Finder 扩展读取同一个值。

## 结构

- `Sources/Core/Localization.swift`：语言模型、系统语言解析、资源加载和简中回退。
- `Resources/Localization.bundle`：宿主界面、Finder 菜单与运行时错误的九种语言资源。
- `Resources/AppLocalizations`：由 macOS 按系统语言读取的 `ServicesMenu.strings`。
- 配置 schema 21 新增 `language`；旧配置迁移时使用 `system`，不改写其他设置。

应用内切换语言后，设置窗口、菜单栏菜单和下一次打开的 Finder 菜单都会使用新语言。Finder 已缓存的工具栏辅助说明可能要在扩展重新载入后更新，但菜单内容不需要重启 Finder。

## 添加或修改文案

源码以简体中文原文作为本地化键。新增用户可见中文文案时，需要在九份 `Localizable.strings` 中加入同一个键，并保留 `%@`、`%d` 等格式占位符。

`make test` 会验证：

1. 源码中的全部中文字符串与简中资源键集合完全一致。
2. 九种语言具有相同且非空的完整键集合。
3. 每个翻译的格式占位符与源文案一致。
4. 语言 Codable、系统语言解析、未知键回退和 schema 20 到 21 的迁移行为。
