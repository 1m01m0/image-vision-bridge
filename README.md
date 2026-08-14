# Image Vision Bridge

[中文](README.zh.md)

**Image Vision Bridge** is an [Agent Skill](https://agentskills.io/specification) that gives text-only LLMs (DeepSeek, etc.) the ability to "see" images.

DeepSeek and most text-only models cannot ingest images directly. This skill bridges the gap with a two-tier pipeline that turns image content into text the model can reason about:

1. **Local engines (default — free, private, zero-dependency)** — macOS Vision multilingual OCR, QR/barcode decoding, face detection, scene classification, dominant colors, and metadata extraction. Nothing leaves your machine.
2. **Third-party multimodal models (optional, on demand)** — an OpenAI-compatible vision API (GLM-4V, Qwen-VL, GPT-4o, DeepSeek-VL2, ...) for real semantic understanding of photos, complex diagrams, and sketches.

## Structure

```text
image-vision-bridge/
├── SKILL.md               # Metadata + model instructions
├── scripts/
│   ├── ocr.sh             # OCR entry point (Vision → tesseract fallback)
│   ├── vision-ocr.jxa     # macOS Vision multilingual OCR (JXA, no compilation)
│   ├── vision-detect.jxa  # QR/barcodes, faces, scene classification
│   ├── image-info.sh      # Dimensions, format, dominant colors, brightness
│   ├── clipboard-image.sh # Save the clipboard image to PNG
│   └── vision-api.sh      # OpenAI-compatible vision API fallback
└── references/
    └── engine-notes.md    # Engine details, providers, troubleshooting
```

## Install

### Claude Code / Codex / OpenCode (Agent Skills)

```sh
# Option 1 (recommended): npx skills
npx skills add 1m01m0/image-vision-bridge

# Option 2: manual
git clone https://github.com/1m01m0/image-vision-bridge ~/.claude/skills/image-vision-bridge
```

### DeepSeek Harness (dsh)

`dsh` auto-discovers skills under `~/.agents/skills/` and `~/.dsh/skills/` (hot-reloaded, no restart needed):

```sh
git clone https://github.com/1m01m0/image-vision-bridge ~/.agents/skills/image-vision-bridge
```

## Optional: vision API configuration

Local engines are free and fully on-device. For semantic-level understanding (photos, complex diagrams), configure any OpenAI-compatible vision model:

```sh
# ~/.dsh/vision.env (chmod 600)
DSH_VISION_API_KEY=sk-your-key
DSH_VISION_API_BASE=https://open.bigmodel.cn/api/paas/v4   # Zhipu GLM (glm-4v-flash is free)
DSH_VISION_MODEL=glm-4v-flash
```

Providers: Zhipu GLM (free tier), Alibaba Qwen, SiliconFlow DeepSeek-VL2, Moonshot, OpenAI, OpenRouter — see `references/engine-notes.md` for details.

## Privacy

- Local engines (OCR / detection / classification / colors) run entirely on-device; no data leaves your machine.
- Calling the vision API sends the image to a third party — the skill asks for your consent first.

## License

[MIT](LICENSE)
