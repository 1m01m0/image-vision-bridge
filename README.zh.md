# Image Vision Bridge

[English](README.md) | 中文

**Image Vision Bridge** 是一个 [Agent Skill](https://agentskills.io/specification)，让纯文本大模型（DeepSeek 等）也能“看见”图片。

DeepSeek 等纯文本模型无法直接读取图片。本 skill 用**双轨方案**把图片内容转换成模型可处理的文本：

1. **本地引擎（默认——免费、隐私、零依赖）**——macOS Vision 多语言 OCR、二维码/条形码解码、人脸检测、场景分类、主色调与元数据提取。全程不出本机。
2. **第三方多模态模型（可选，按需）**——通过 OpenAI 兼容接口接入 GLM-4V、Qwen-VL、GPT-4o、DeepSeek-VL2 等视觉大模型，真正“看懂”照片、复杂图表和手绘草图。

## 目录结构

```text
image-vision-bridge/
├── SKILL.md               # 元数据 + 模型指令
├── scripts/
│   ├── ocr.sh             # OCR 主入口（Vision → tesseract 回退）
│   ├── vision-ocr.jxa     # macOS Vision 多语言 OCR（JXA，免编译）
│   ├── vision-detect.jxa  # 二维码/条形码、人脸、场景分类
│   ├── image-info.sh      # 尺寸、格式、主色调、亮度
│   ├── clipboard-image.sh # 把剪贴板图片存为 PNG
│   └── vision-api.sh      # OpenAI 兼容视觉 API 兜底
└── references/
    └── engine-notes.md    # 引擎细节、供应商与排障
```

## 安装

### Claude Code / Codex / OpenCode（Agent Skills）

```sh
# 方式一（推荐）：npx skills
npx skills add 1m01m0/image-vision-bridge

# 方式二：手动安装
git clone https://github.com/1m01m0/image-vision-bridge ~/.claude/skills/image-vision-bridge
```

### DeepSeek Harness（dsh）

`dsh` 会自动扫描 `~/.agents/skills/` 与 `~/.dsh/skills/`（热刷新，无需重启）：

```sh
git clone https://github.com/1m01m0/image-vision-bridge ~/.agents/skills/image-vision-bridge
```

## 可选：视觉 API 配置

本地引擎免费且完全在本机运行。需要语义级理解（照片、复杂图表）时，配置任意 OpenAI 兼容的视觉模型：

```sh
# ~/.dsh/vision.env（权限 600）
DSH_VISION_API_KEY=sk-你的密钥
DSH_VISION_API_BASE=https://open.bigmodel.cn/api/paas/v4   # 智谱 GLM（glm-4v-flash 免费）
DSH_VISION_MODEL=glm-4v-flash
```

可用供应商：智谱 GLM（免费额度）、阿里百炼 Qwen、硅基流动 DeepSeek-VL2、Moonshot、OpenAI、OpenRouter——详见 `references/engine-notes.md`。

## 隐私

- 本地引擎（OCR/检测/分类/颜色）全部在本机运行，不上传任何数据。
- 调用视觉 API 时图片会发送给第三方——skill 会先征得你的同意。

## License

[MIT](LICENSE)
