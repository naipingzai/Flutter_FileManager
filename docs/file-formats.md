# 文件格式支持规划（路线图）

> 目标：导入后能预览/解析尽可能多的文件格式。按类别分阶段逐一集成。
> 每个类别对应 `core/media`（或新增 core/<category>）模块 + 预编译解码库。
> 原则：解码库统一由 Flutter_CrossPlatformDependency 编译为预编译库，
> 本仓库 vendor 进 `third_party/` 后直接链接（不下载、不本地编译）。

## 阶段一：基础类型（当前已支持，经 FFmpeg/miniz/stb_image）
| 类别 | 格式 | 解码库 |
|------|------|--------|
| 图片 | jpg/png/gif/bmp/webp/tiff/ico | stb_image |
| 视频 | mp4/mkv/mov/webm/avi/flv/3gp | FFmpeg |
| 音频 | mp3/wav/flac/aac/ogg/m4a/opus | FFmpeg |
| 压缩包 | zip | miniz |
| 电子书 | epub | miniz |
| 文本 | txt/log/md/json/xml/yaml/ini/js/py/... | 内置文本读取 |

## 阶段二：办公文档（规划）
| 格式 | 说明 | 依赖 |
|------|------|------|
| PDF | 渲染 + 文本提取 | PDFium 或 poppler |
| DOCX/XLSX/PPTX | Office Open XML（本质 zip + XML） | miniz（已有）+ XML 解析 |
| ODT/ODS/ODP | OpenDocument | miniz + XML |
| CSV/TSV | 表格 | 内置 |

## 阶段三：图片增强（规划）
| 格式 | 说明 | 依赖 |
|------|------|------|
| HEIC/HEIF | iOS 常用 | libheif |
| AVIF | 新一代图片 | libavif |
| SVG | 矢量 | resvg / librsvg |
| PSD/RAW | 相机格式 | 可选 libraw |
| 图片缩略图统一 | 所有格式生成缩略图 | stb_image / libavif |

## 阶段四：压缩/归档增强（规划）
| 格式 | 说明 | 依赖 |
|------|------|------|
| 7z | 高压缩比 | lib7zip / p7zip |
| RAR | 专有 | unrar |
| TAR/GZ/BZ2/XZ | tar 家族 | libarchive |
| ISO | 光盘镜像 | libarchive |

## 阶段五：其它（规划）
| 类别 | 格式 | 依赖 |
|------|------|------|
| 电子书扩展 | mobi/azw3/pdf | 各专有库 |
| 字幕 | srt/ass/vtt | 内置文本 |
| 代码/语法高亮 | 各语言 | 前端高亮 |
| 数据库文件 | sqlite/db | sqlite（与数据库模块共用） |

## 集成方式

每个格式类别：
1. 在 Flutter_CrossPlatformDependency 增加对应解码库的编译 workflow（遵循其 README）。
2. 本仓库 vendor 预编译库到 `third_party/`。
3. 在 `core/media`（或新 core/<category>）实现解析 + FFI。
4. 前端 viewer 页面接入。

> 当前优先级：**先完成数据库 + 标签系统（docs/architecture.md）**，
> 文件格式按上述阶段逐步集成，不阻塞数据库/标签主流程。
