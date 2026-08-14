# Image Vision Bridge

[中文](README.zh.md)

**Image Vision Bridge** is an [Agent Skill](https://agentskills.io/specification) that gives text-only LLMs (DeepSeek, etc.) the ability to "see" images.

DeepSeek and most text-only models cannot ingest images directly. This skill bridges the gap with a two-tier pipeline that turns image content into text the model can reason about:

1. **Local engines (default — free, private, zero-dependency)** — macOS Vision multilingual OCR, QR/barcode decoding, face detection, scene classification, dominant colors, and metadata extraction. Nothing leaves your machine.
2. **Third-party multimodal models (optional, on demand)** — an OpenAI-compatible vision API (GLM-4V, Qwen-VL, GPT-4o, DeepSeek-VL2, ...) for real semantic understanding of photos, complex diagrams, and sketches.

## Scope and use cases

This is an **Agent Skill and explicit image toolbox**. It is intended for a user-confirmed image source and a specific processing task; it is not the chat-attachment routing plugin for DeepSeek Harness.

| Need | Use |
| --- | --- |
| OCR, QR/barcode decoding, colors, or metadata for a known local file | **`image-vision-bridge`** |
| Explicit clipboard capture or local upload fallback when a GUI cannot attach an image | **`image-vision-bridge`** |
| Manual vision-API analysis of a specified file in a text-only agent without image routing | **`image-vision-bridge`** |
| Send an image in DeepSeek Harness while a DeepSeek model is selected | [`dsh-image-router`](https://github.com/1m01m0/dsh-image-router) |
| Automatically let MiniMax-M3 (or another vision model) inspect an image and let DeepSeek answer | `dsh-image-router` |
| Use a model that already accepts image input natively | Usually neither |

### Relationship to dsh-image-router

- `dsh-image-router` is the **Harness orchestration layer**: it handles chat attachments, calls the configured vision model once, and passes a text description to DeepSeek.
- `image-vision-bridge` is the **explicit tool layer**: it works with a known path, clipboard image, or local upload and specializes in OCR, codes, and image information.
- They can be installed together, but this skill must not rediscover or re-analyze the same chat attachment already handled by `dsh-image-router`.
- To use this skill in Harness, prefer a new conversation without an image attachment and provide an exact local path and task, for example: “Run local-only OCR on `/path/to/a.png`.”

### Out of scope and safety boundaries

- Do not scan workspaces, Downloads, Desktop, temporary folders, or attachment directories to guess which image the user means.
- Do not treat the most recently modified image as the requested image; ask the user when the path is unclear.
- Do not identify real people, search the web for a person, or bypass a vision provider's safety restrictions.
- Before calling a third-party vision API, state that the image will leave the machine and obtain consent for that specific transmission.
- If the user requests local-only processing, use only the local OCR, code detection, classification, color, and metadata tools.

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

> If your goal is to attach images in chat while using DeepSeek, install [`dsh-image-router`](https://github.com/1m01m0/dsh-image-router); this skill is not required for that automatic workflow. Install this skill in dsh only when you need explicit local OCR, code decoding, image information, or a manual upload fallback.

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
- Clipboard capture and the local upload page should only be used after an explicit user request.
- Calling the vision API sends the image to a third party; disclose the target service and obtain consent before each transmission.
- The skill should not scan directories to discover images or substitute unrelated local files for the current attachment.

## License

[MIT](LICENSE)
