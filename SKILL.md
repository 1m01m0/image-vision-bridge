---
name: image-vision-bridge
description: 'Give text-only LLMs (DeepSeek, etc.) the ability to see images: OCR all visible text, read QR codes and barcodes, detect faces, classify scenes, extract colors and metadata, and optionally describe photos/diagrams through a user-provided vision API. Use whenever the user attaches, pastes, links, or names an image, photo, screenshot, scan, diagram, chart, or QR code, or asks about the contents of a picture file.'
license: MIT
compatibility: 'macOS only. Uses osascript (JXA) + built-in Vision framework, sips, python3+PIL, and optional tesseract/curl. No installs required for the primary path.'
metadata:
  author: 1m01m0
allowed-tools: Bash
---

# Image Vision Bridge — 让纯文本模型“看见”图片

DeepSeek 等纯文本模型无法直接读取图片。本 skill 用**双轨方案**把图片内容转换成文本：

1. **本地引擎（默认，零依赖、免费、隐私）**——macOS Vision OCR（多语言）、二维码/条形码、人脸、场景分类、主色调、元数据。适合截图、文档、票据、扫码、图表标签等。
2. **第三方多模态模型（可选，按需）**——通过 OpenAI 兼容接口接入 GLM-4V / Qwen-VL / GPT-4o / DeepSeek-VL2 等视觉大模型，真正“看懂”照片、复杂图表、手绘草图的语义。**这是让 DeepSeek 获得完整视觉理解能力的推荐路径**，只需用户提供一个 API Key。

**核心原则**
- 不要尝试 `read_image` 或声称“看到了”图片——你只能基于引擎输出的文本证据说话，并在回答中注明来源（如 `Vision OCR` / `GLM-4V`）。
- 本地引擎优先（免费、隐私、无网络依赖）；语义理解/看图说话才需要第三方模型，且**调用前必须告知用户图片会发送到第三方并征得同意**。

## Bundled Resources

`SKILL_DIR` = 包含本 SKILL.md 的目录（即 skill 加载结果中的 resourceBase）。所有脚本都在 `$SKILL_DIR/scripts/` 下：

| 脚本 | 作用 |
| --- | --- |
| `ocr.sh` | 主入口：把图片归一化为 PNG 后先用 macOS Vision 做多语言 OCR（默认 zh-Hans,en-US），失败时回退 tesseract。输出每行文字 + 置信度 + 归一化坐标框。 |
| `vision-detect.jxa` | QR/条形码（含 payload）、人脸数量、场景分类（top5）。 |
| `image-info.sh` | 尺寸/格式/DPI/色彩空间/文件大小 + 主色调 + 平均亮度。 |
| `clipboard-image.sh` | 把剪贴板里的图片存成 PNG（用户“粘贴截图”时用）。 |
| `vision-api.sh` | OpenAI 兼容视觉 API 兜底（需用户提供 `DSH_VISION_API_KEY` 等环境变量）。 |

## Workflow

1. **定位图片**：
   - 本地路径：直接用。
   - 对话附件：先找到文件实际路径（检查工作区/附件目录，必要时用 glob）。
   - URL：`curl -L -o /tmp/img.jpg "<url>"` 下载。
   - 剪贴板粘贴：`bash "$SKILL_DIR/scripts/clipboard-image.sh" /tmp/pasted.png`。
   - 若找不到任何图片文件，向用户确认图片来源。

2. **基本信息**：`bash "$SKILL_DIR/scripts/image-info.sh" <image>` → 尺寸、格式、主色调、明暗。

3. **读文字**：`bash "$SKILL_DIR/scripts/ocr.sh" <image>`（可按需加语言参数，如 `"en-US"`、`"ja-JP,zh-Hans"`）。
   - 输出形如 `[box 12%,3% 76x8] 文本行`，坐标为相对整图的百分比（左上原点），可用于回答“文字在哪个位置”。

4. **查码与场景**：`osascript -l JavaScript "$SKILL_DIR/scripts/vision-detect.jxa" <image>` → 二维码内容、条形码、人脸数、场景分类。
   - 二维码/条形码的 payload 直接按文本汇报（如链接、订单号、WiFi 配置）。

5. **第三方多模态模型（看图说话）**——本地引擎只能“读字、扫码、分类”，不能真正理解照片内容。当用户需要以下能力时，向用户说明并请求 API Key（国内常用免费/低价选项：智谱 `glm-4v-flash`、阿里 `qwen-vl-plus`、硅基流动 `deepseek-ai/deepseek-vl2`；海外：OpenAI `gpt-4o-mini`、Moonshot、OpenRouter）：
   ```
   export DSH_VISION_API_KEY=sk-xxx \
          DSH_VISION_API_BASE=https://open.bigmodel.cn/api/paas/v4 \
          DSH_VISION_MODEL=glm-4v-flash
   bash "$SKILL_DIR/scripts/vision-api.sh" <image> ["自定义提问"]
   ```
   - 脚本输出就是模型的文字描述；可传第二个参数自定义提问（如“图里是什么产品？价格多少？”）。
   - 没有 Key 时脚本会给出清晰报错；此时向用户解释本地引擎已提供的结果，并询问是否愿意配置视觉 API。
   - 用户若已填写过 `~/.dsh/vision.env`（模板已生成，含注释说明），直接使用即可，无需再问 Key。
   - 配置优先级：`~/.dsh/vision.env` 文件 > 环境变量（`DSH_VISION_ENV_FILE` 可指定其他路径，`/dev/null` 可禁用文件）。

6. **汇总回答**：
   - 用用户的语言输出；把 OCR 文字原样引用（不要润色/脑补），坐标信息用于描述布局。JXA 桥接无法提供真实置信度，所有识别行均视为已识别文本。
   - 明确标注每条信息的来源与置信度；低置信度（<0.5）或缺失的部分要说明。
   - 图里有文字→先给全文，再给“哪里写了什么”的布局总结。

## Engine selection

| 场景 | 引擎 | 备注 |
| --- | --- | --- |
| 截图/文档/票据/多语言文字 | Vision OCR（`ocr.sh`） | 本地、支持中文英文日文等；自动纠倾斜 |
| 二维码/条形码 | `vision-detect.jxa` | 直接给出解码内容 |
| 照片场景/物体大致类别 | `vision-detect.jxa` 分类 + 主色调 | 只有粗粒度标签，无法细读照片 |
| 需要深入理解照片/复杂图表/手绘图 | `vision-api.sh`（用户提供 Key） | 数据会发送给第三方，先征得用户同意；推荐 `glm-4v-flash`（免费）或 `qwen-vl-plus` |
| 纯英文低质量图 | tesseract 回退 | 仅当 Vision 失败时自动启用 |

## Privacy

- 本地引擎（OCR/检测/分类/颜色/元数据）全部在本机运行，不上传任何数据。
- `vision-api.sh` 会把图片 base64 发送到第三方服务：**调用前必须告知用户并征得同意**。

## Troubleshooting

- HEIC/WebP/GIF：`ocr.sh` 会自动转 PNG（PIL 优先，sips 兜底）；动图取第一帧。
- 多页 PDF：本管线只处理第一页（PIL）；需要逐页时用 `sips -s format png <pdf> --out <dir>` 或 `pdftoppm` 逐页转图后循环调用。
- 超大图：`ocr.sh` 会把宽度压到 4096px 以内再识别。
- Vision 对长 URL/细密小字偶尔截断：可配合 `vision-detect`/坐标框拼读，或建议用户放大后重试。
- 中文支持：Vision 原生支持；tesseract 需 `brew install tesseract-lang` 才有 `chi_sim`。
- 脚本报 `ERROR:` 开头即引擎失败，不要当作识别结果。

更多细节见 `references/engine-notes.md`。
