# Engine notes (image-vision-bridge)

## macOS Vision via JXA (primary engine)

- Invoked with `osascript -l JavaScript vision-ocr.jxa <png> [langs]`; the Vision framework is Apple's on-device OCR/vision stack (same engine behind Live Text).
- Language codes use Vision naming: `zh-Hans`, `en-US`, `ja-JP`, `ko-KR`, `fr-FR`, `de-DE`, `es-ES`, `it-IT`, `pt-BR`, `ru-RU`, `tr-TR`, `th-TH`, `vi-VN`, `uk-UA`, `pl-PL`, `ro-RO`, `nb-NO`, `sv-SE`, `da-DK`, `fi-FI`, `el-GR`, `cs-CZ`, `hu-HU`, `hr-HR`, `sk-SK`, `he-IL`, `ar-SA`...
- `recognitionLevel` = Accurate; `usesLanguageCorrection` = true. Rotated/skewed text is handled natively.
- Output lines: `[box x%,y% w xh] text` — normalized percentages, top-left origin.
- Known quirks: very long URLs or dense tiny text may be split/truncated. The JXA ObjC bridge cannot expose Vision's real confidence values (always reads 0.5), so per-line confidence is omitted; every emitted line is recognized text.
- If osascript crashes (exit 139) on an exotic image, ocr.sh falls back to tesseract automatically.

## tesseract (fallback)

- `tesseract <png> stdout -l eng`; installed via Homebrew at /opt/homebrew/bin/tesseract with eng/osd/snum only by default.
- For Chinese: `brew install tesseract-lang`, then use `-l chi_sim` (update ocr.sh LANGS mapping if needed).

## Vision detection (vision-detect.jxa)

- VNDetectBarcodesRequest: QR, Code128, EAN13, PDF417, Aztec, DataMatrix, etc. `payloadStringValue` is the decoded content.
- VNDetectFaceRectanglesRequest: count only (no identity).
- VNClassifyImageRequest: coarse scene tags (e.g. "screenshot", "text", "outdoor", "food") with confidence, top 5.

## Image info (image-info.sh)

- sips: format, pixelWidth/Height, dpi, color space, alpha.
- PIL: top-5 dominant colors (quantized) + average brightness. Pure heuristics — never "prove" content from colors alone.

## vision-api.sh (optional cloud fallback)

- OpenAI-compatible `chat/completions` with a base64 data URL image. Env: DSH_VISION_API_KEY / DSH_VISION_API_BASE / DSH_VISION_MODEL.
- Known providers (all OpenAI-compatible `chat/completions`):
  | Provider | Base URL | Model | Cost |
  | --- | --- | --- | --- |
  | Zhipu GLM (智谱) | https://open.bigmodel.cn/api/paas/v4 | glm-4v-flash | free tier |
  | Alibaba Qwen (阿里百炼) | https://dashscope.aliyuncs.com/compatible-mode/v1 | qwen-vl-plus | cheap |
  | SiliconFlow (硅基流动) | https://api.siliconflow.cn/v1 | deepseek-ai/deepseek-vl2 | free tier |
  | Moonshot (月之暗面) | https://api.moonshot.cn/v1 | moonshot-v1-8k-vision-preview | paid |
  | OpenAI | https://api.openai.com/v1 | gpt-4o-mini | paid |
  | OpenRouter | https://openrouter.ai/api/v1 | qwen/qwen-2.5-vl-72b-instruct | free tier options |
- Privacy: the image leaves the machine. Always ask the user first.

## Typical flows

1. Screenshot with text → ocr.sh (Vision) + image-info.sh.
2. QR code photo → vision-detect.jxa (barcode payload) + ocr.sh.
3. Photo of a scene → image-info.sh (colors/brightness) + vision-detect.jxa (classification) + optionally vision-api.sh after user consent.
4. Receipt/invoice/ID card → ocr.sh with zh-Hans,en-US; report all fields verbatim.
5. Diagram/chart → ocr.sh (labels) + vision-detect classification; if structure matters, ask user for consent to use vision-api.sh.

## Failure policy

- Any script output starting with `ERROR:` means the engine failed — report the error, do not fabricate content.
- `(no text found)` from Vision is a real answer (image has no text), not a failure.
- If all local engines fail and no API key exists, tell the user exactly what was attempted and what would be needed to go further.
