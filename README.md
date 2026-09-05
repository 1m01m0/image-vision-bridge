# Image Vision Bridge

English | [简体中文](README.zh.md)

An Agent Skill and command-line image toolbox that turns a specified image into text: OCR, barcode payloads, face counts, scene labels, image metadata, and approximate dominant colors. An optional vision API can provide a richer description when local extraction is insufficient.

The local pipeline targets **macOS** and uses Apple Vision through JavaScript for Automation (JXA). It is useful with text-only agents, or when a task specifically needs OCR and structured image information.

## Quick start: local image processing

Requires macOS with the relevant Vision APIs, `osascript`, Bash, and Python 3. Pillow is needed for color analysis and the preferred image-normalization path; OCR can fall back to macOS `sips` for normalization. Tesseract with English language data is an optional OCR fallback.

```bash
git clone https://github.com/1m01m0/image-vision-bridge.git
cd image-vision-bridge
python3 -m venv .venv
source .venv/bin/activate
python -m pip install Pillow

bash scripts/ocr.sh /absolute/path/to/image.png
bash scripts/image-info.sh /absolute/path/to/image.png
osascript -l JavaScript scripts/vision-detect.jxa /absolute/path/to/image.png
```

These commands process the specified local file without calling the vision API. OCR defaults to Simplified Chinese and US English; override with a comma-separated Vision language list:

```bash
bash scripts/ocr.sh /absolute/path/to/image.png 'zh-Hans,en-US'
```

Results are printed as text. OCR accuracy depends on resolution, layout, supported languages, and the engine. Detection reports face counts, not identities; scene labels are broad classifications, not a detailed semantic description.

## Install as an Agent Skill

Use the `skills` CLI (requires Node.js / npm and network access):

```bash
npx skills add 1m01m0/image-vision-bridge
```

Alternatively, place the cloned directory in your agent's supported Skill directory, retaining the relative paths under [SKILL.md](SKILL.md). For example, a Claude Code installation can use `~/.claude/skills/image-vision-bridge`. Verify the discovery path for your particular agent.

Ask for a known file and a specific operation:

```text
Use image-vision-bridge for local-only OCR on /absolute/path/to/receipt.png.
Extract the visible text and mark uncertain characters.
```

The Skill must not search Downloads, Desktop, workspaces, temporary directories, or attachment folders to guess which image you mean. When the path is unclear, the agent should ask for it.

## Choose the right tool

| Task | Entry point |
| --- | --- |
| OCR | `bash scripts/ocr.sh IMAGE [LANGUAGES]` |
| QR/barcodes, face count, scene classification | `osascript -l JavaScript scripts/vision-detect.jxa IMAGE` |
| Metadata, colors, brightness | `bash scripts/image-info.sh IMAGE` |
| Explicitly save the current clipboard image | `bash scripts/clipboard-image.sh /absolute/path/to/output.png` |
| Optional remote image description | `bash scripts/vision-api.sh IMAGE [PROMPT] [MAX_TOKENS]` |
| Experimental local upload helper | `python3 scripts/upload-server.py [PORT] [OUTDIR]` |

Clipboard capture requires an explicit request and macOS pasteboard access. It writes the selected output path; use a new filename to preserve existing files.

### Relationship to dsh-image-router

[`dsh-image-router`](https://github.com/1m01m0/dsh-image-router) handles image-attachment routing in DeepSeek Harness. Image Vision Bridge provides explicit image processing from a known path, clipboard capture, or a manually selected upload. They serve separate steps and can coexist, but an agent must not rediscover or re-analyze an attachment already handled by the router.

For this Skill in Harness, use an explicit local path and task, preferably in a conversation without an image attachment. If a model already accepts images directly, native attachment handling may be sufficient.

## Optional vision API

Calling `vision-api.sh` sends the image and prompt to the configured third party. **State the destination and obtain the user's consent for that specific transmission before running it.** The script itself does not display a confirmation prompt. If the user requests local-only processing, do not call it.

The adapter expects an OpenAI-compatible `/chat/completions` endpoint that accepts an image data URL. Configure:

| Variable | Default / meaning |
| --- | --- |
| `DSH_VISION_API_KEY` | Required API key. |
| `DSH_VISION_API_BASE` | `https://api.openai.com/v1`; base URL without `/chat/completions`. |
| `DSH_VISION_MODEL` | `gpt-4o-mini`; choose a vision-capable model supported by your provider. |
| `DSH_VISION_ENV_FILE` | `~/.dsh/vision.env`; optional configuration file path. |

The default model is a value in the script, not a guarantee of provider availability or account access. The script sources the configuration file as **shell code**, and values assigned there override existing environment values. Use only a trusted file and restrict its permissions; do not commit it or share its contents.

After configuring credentials securely and obtaining consent, a request can be made with:

```bash
bash scripts/vision-api.sh /absolute/path/to/diagram.png \
  'Explain the components and arrows; mark unreadable labels.' 1024
```

The script sends the original file as base64 without resizing it, uses a 120-second curl timeout, and defaults to 1,024 output tokens. It additionally requires `curl`, `file`, `base64`, and Python 3. Large images or unsupported formats can exceed provider limits. Some provider errors are printed without a failing process status, so inspect the response text rather than relying solely on exit status.

## Experimental upload helper

`upload-server.py` binds to `127.0.0.1` (default port 8765) and stores uploads in `/tmp/vision-uploads` by default. It has no authentication or upload-size limit and writes received bytes with a `.png` filename without converting their format. Stop it with Ctrl+C after use, and remove saved uploads when no longer needed.

The current page's paste/drop handler mistakenly reads the event-type string instead of the event object, so the browser upload workflow may not submit images. Use an explicit file path or the clipboard script until that handler is fixed. The server is an optional helper, not required for OCR or detection.

## Limits, privacy, and troubleshooting

- Apple Vision OCR, barcode detection, face detection, scene classification, and clipboard access require macOS. Linux/Windows support is not complete; a Pillow/Tesseract OCR fallback alone does not provide all features.
- OCR normalization uses the first image frame. The Pillow path converts to RGB and caps width at 4,096 pixels; the `sips` fallback does not apply the same resizing logic. Format support depends on installed image decoders.
- Tesseract is used only after Vision errors, with English data; empty or inaccurate successful Vision output does not trigger a second pass.
- `No module named PIL` means Pillow is missing from the Python environment used by the script. Missing Vision support or unsupported image formats can also cause failures.
- Local image commands make no model request. If an agent reads their extracted text, that text enters the agent's conversation and is handled by its service.
- Do not identify real people, search for a person's identity, or bypass provider restrictions. Preserve uncertainty in OCR and model descriptions.

## Development and support

Start with [SKILL.md](SKILL.md), the [scripts](scripts), and [engine notes](references/engine-notes.md). The repository has no automated test suite. Validate changes using non-sensitive fixtures for OCR, barcodes, unsupported formats, and missing dependencies; do not exercise clipboard capture or remote APIs without an explicit request.

For [issues](https://github.com/1m01m0/image-vision-bridge/issues), include macOS/Python versions, the command, and a sanitized error. Share an image only if you have permission; never include credentials.

## License

[MIT](LICENSE). Copyright © 2026 1m01m0.
