# 内置模板来源

`Resources/Templates` 中的三份 WPS 兼容空白文档由本项目独立生成，不包含或复制“超级右键”的模板内容。

生成过程：

1. 使用 `FileOperations.createOfficeDocument` 创建空白 DOCX、XLSX、PPTX。
2. 使用 LibreOffice headless 模式分别转换为 Word 97、Excel 97、PowerPoint 97 的 OLE 复合文档。
3. 将扩展名设为 WPS Office 对应的 `.wps`、`.et`、`.dps`。
4. 使用 `file`、单元测试和 WPS Office 12.1 实际打开验证格式。

当前文件的 SHA-256：

```text
44b5a25fc51adff86301925b4e7f57f28edab56daaeda96bb1b64cc46fd155f4  Blank.wps
f276982aba5562e528c551baef0774953c0ef91034f0297e821b9257a4157dfa  Blank.et
3e832e5a18ef5f332841f52afc3182507d2a4ffe7515ba8dc27ce63be64e1065  Blank.dps
```

单元测试还会检查 OLE 文件头，并拒绝带有 `Author` 或 `Last Saved By` 元数据的模板。
