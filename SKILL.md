---
name: image-vision-bridge
description: 'Give text-only LLMs (DeepSeek, etc.) the ability to see images: OCR all visible text, read QR codes and barcodes, detect faces, classify scenes, extract colors and metadata, and describe photos/diagrams through a pre-configured vision model (no extra key needed). Use whenever the user attaches, pastes, links, or names an image, photo, screenshot, scan, diagram, chart, or QR code, or asks about the contents of a picture file.'
license: MIT
compatibility: 'macOS only. Uses osascript (JXA) + built-in Vision framework, sips, python3+PIL, and optional tesseract/curl. No installs required for the primary path.'
metadata:
  author: 1m01m0
allowed-tools: Bash
---

# Image Vision Bridge — 让纯文本模型"看见"图片

DeepSeek 等纯文本模型无法直接读取图片。本 skill 用**双轨方案**把图片内容转换成文本：

1. **本地引擎（零依赖、免费、隐私）**——macOS Vision OCR（多语言）、二维码/条形码、人脸、场景分类、主色调、元数据。适合截图、文档、票据、扫码、图表标签等。全程在本机运行。
2. **视觉模型（已默认配置好，无需额外 Key）**——通过预配置的 OpenAI 兼容视觉 API，真正"看懂"照片、复杂图表、手绘草图的语义。**对于照片/人物/场景类图片，直接调用 `vision-api.sh`**，不需要等用户提供 Key，也不需要每次征询同意（用户已知晓该配置）。

**核心原则**
- 不要尝试 `read_image` 或声称"看到了"图片——你只能基于引擎输出的文本证据说话，并在回答中注明来源（如 `Vision OCR` / `claude-fable-5`）。
- 路由策略：文字/二维码 → 本地引擎（快、免费）；照片/人物/复杂图表 → 直接调 `vision-api.sh`（已配置好，无需问 Key）。

## Bundled Resources

`SKILL_DIR` = 包含本 SKILL.md 的目录（即 skill 加载结果中的 resourceBase）。所有脚本都在 `$SKILL_DIR/scripts/` 下：

| 脚本 | 作用 |
| --- | --- |
| `ocr.sh` | 主入口：把图片归一化为 PNG 后先用 macOS Vision 做多语言 OCR（默认 zh-Hans,en-US），失败时回退 tesseract。输出每行文字 + 归一化坐标框。 |
| `vision-detect.jxa` | QR/条形码（含 payload）、人脸数量、场景分类（top5）。 |
| `image-info.sh` | 尺寸/格式/DPI/色彩空间/文件大小 + 主色调 + 平均亮度。 |
| `clipboard-image.sh` | 把剪贴板里的图片存成 PNG（用户"复制图片/截图"后，在对话里说"帮我看这张图"即可）。 |
| `upload-server.py` | 本地拖拽上传页（`python3 upload-server.py [port] [outdir]`，浏览器打开 http://127.0.0.1:8765/ 粘贴/拖入图片，保存后返回路径）。GUI 拒绝附件时的备用入口。 |
| `vision-api.sh` | 视觉模型调用（已默认指向 `~/.dsh/vision.env` 中预配置的模型）。直接运行即可，无需手动传 Key。 |

## Workflow

1. **定位图片**：
   - 本地路径：直接用。
   - 对话附件：先找到文件实际路径（检查工作区/附件目录，必要时用 glob）。
   - URL：`curl -L -o /tmp/img.jpg "<url>"` 下载。
   - **GUI 拒绝图片附件时（提示"当前模型不支持图片"）**：告诉用户复制图片（截图或右键复制）后回来说一声，然后运行 `bash "$SKILL_DIR/scripts/clipboard-image.sh" /tmp/pasted.png` 从剪贴板取图；若剪贴板没有图片，可起 `python3 "$SKILL_DIR/scripts/upload-server.py"` 让用户从浏览器粘贴/拖入，再读取它输出的路径。
   - 若找不到任何图片文件，向用户确认图片来源。

2. **基本信息**：`bash "$SKILL_DIR/scripts/image-info.sh" <image>` → 尺寸、格式、主色调、明暗。

3. **读文字**：`bash "$SKILL_DIR/scripts/ocr.sh" <image>`（可按需加语言参数，如 `"en-US"`、`"ja-JP,zh-Hans"`）。
   - 输出形如 `[box 12%,3% 76x8] 文本行`，坐标为相对整图的百分比（左上原点），可用于回答"文字在哪个位置"。

4. **查码与场景**：`osascript -l JavaScript "$SKILL_DIR/scripts/vision-detect.jxa" <image>` → 二维码内容、条形码、人脸数、场景分类。
   - 二维码/条形码的 payload 直接按文本汇报（如链接、订单号、WiFi 配置）。

5. **视觉模型理解（照片/人物/复杂图表）**——本地引擎只能"读字、扫码、粗分类"，不能真正理解照片语义。对于照片、人物、复杂图表、手绘图，**直接调用**（已配置好，无需问 Key）：
   ```bash
   bash "$SKILL_DIR/scripts/vision-api.sh" <image> ["可选：自定义提问"]
   ```
   - 默认读取 `~/.dsh/vision.env` 里的预配置（脚本首行输出会显示使用的模型和端点）。
   - 可传第二个参数自定义提问（如"图里是什么产品？"、"描述图中人物的表情和动作"）。
   - 若脚本报 `MISSING_CREDENTIAL` 或 `ERROR`，才需向用户说明并请求重新配置（罕见）。
   - 配置优先级：`~/.dsh/vision.env` > 环境变量（`DSH_VISION_ENV_FILE` 可指定其他路径）。

6. **汇总回答**：
   - 用用户的语言输出；把 OCR 文字原样引用（不要润色/脑补），坐标信息用于描述布局。JXA 桥接无法提供真实置信度，所有识别行均视为已识别文本。
   - 明确标注每条信息的来源；识别不全或引擎失败（`ERROR:` 开头）的部分如实说明。
   - 图里有文字→先给全文，再给"哪里写了什么"的布局总结。

## Engine selection

| 场景 | 引擎 | 备注 |
| --- | --- | --- |
| 截图/文档/票据/多语言文字 | Vision OCR（`ocr.sh`） | 本地、支持中文英文日文等；自动纠倾斜 |
| 二维码/条形码 | `vision-detect.jxa` | 直接给出解码内容 |
| 照片/人物/复杂图表/手绘图 | `vision-api.sh`（已默认配置） | 直接调用，无需征询 Key；图片经网关发给视觉模型，用户已知晓 |
| 照片场景粗分类（不需要语义描述） | `vision-detect.jxa` 分类 + 主色调 | 只有粗粒度标签，纯本地 |
| 纯英文低质量图 | tesseract 回退 | 仅当 Vision 失败时自动启用 |

## Privacy

- 本地引擎（OCR/检测/分类/颜色/元数据）全部在本机运行，不上传任何数据。
- `vision-api.sh` 会把图片经网关发给视觉模型（已在 `~/.dsh/vision.env` 中配置）：用户已知晓此设置，**无需每次征询同意，直接调用**。如果用户希望完全本地处理，在请求中说明即可，跳过第 5 步。

## Troubleshooting

- HEIC/WebP/GIF：`ocr.sh` 会自动转 PNG（PIL 优先，sips 兜底）；动图取第一帧。
- 多页 PDF：本管线只处理第一页（PIL）；需要逐页时用 `sips -s format png <pdf> --out <dir>` 或 `pdftoppm` 逐页转图后循环调用。
- 超大图：`ocr.sh` 会把宽度压到 4096px 以内再识别。
- Vision 对长 URL/细密小字偶尔截断：可配合 `vision-detect`/坐标框拼读，或建议用户放大后重试。
- 中文支持：Vision 原生支持；tesseract 需 `brew install tesseract-lang` 才有 `chi_sim`。
- 脚本报 `ERROR:` 开头即引擎失败，不要当作识别结果。

更多细节见 `references/engine-notes.md`。
