# Third-party notices

## libwebp

灵犀右键随应用分发一个通用架构的 `webp-encoder` 辅助程序。该程序的图像读取层由本项目使用 macOS ImageIO 独立实现，WebP 编码层静态链接 Google libwebp 1.6.0，并以 macOS 13 为最低部署目标构建。

libwebp Copyright (c) 2010, Google Inc. All rights reserved.

libwebp 采用 BSD 3-Clause 风格许可，并附带额外专利授权。完整文本见 `Resources/ThirdParty/libwebp-COPYING.txt` 与 `Resources/ThirdParty/libwebp-PATENTS.txt`；对应源代码可从 [Google WebP 官方下载页](https://developers.google.com/speed/webp/download) 获取。

灵犀右键自身的 MIT License 不覆盖静态链接的 libwebp 代码。
