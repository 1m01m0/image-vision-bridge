# Image Vision Bridge

> 让纯文本大模型（DeepSeek 等）也能“看见”图片的 Agent Skill。
> 遵循 [Anthropic Agent Skills 规范](https://agentskills.io/specification)（frontmatter + SKILL.md + scripts/references）。

DeepSeek 等纯文本模型无法直接读取图片。本 skill 用**双轨方案**把图片内容转换成模型可处理的文本：

1. **本地引擎（默认，零依赖、免费、隐私）**——macOS Vision 多语言 OCR、二维码/条形码解码、人脸检测、场景分类、主色调与元数据提取。
2. **第三方多模态模型（可选，按需）**——通过 OpenAI 兼容接口接入 GLM-4V / Qwen-VL / GPT-4o / DeepSeek-VL2 等视觉大模型，真正“看懂”照片、复杂图表、手绘草图的语义。

## 结构

```
image-vision-bridge/
├── SKILL.md           # 元数据（frontmatter）+ 模型指令
├── scripts/
│   ├── ocr.sh             # OCR 主入口（Vision → tesseract 回退）
│   ├── vision-ocr.jxa     # macOS Vision 多语言 OCR（JXA，无编译依赖）
│   ├── vision-detect.jxa  # 二维码/条形码/人脸/场景分类
│   ├── image-info.sh      # 尺寸/格式/主色调/亮度
│   ├── clipboard-image.sh # 把剪贴板图片存为 PNG
│   └── vision-api.sh      # OpenAI 兼容视觉 API 兜底
└── references/
    └── engine-notes.md    # 引擎细节、供应商与排障
```

## 安装

**Claude Code / Codex / OpenCode 等支持 Agent Skills 的工具**：

```bash
# 方式一（推荐）：npx skills
npx skills add 1m01m0/image-vision-bridge

# 方式二：手动安装到用户级 skills 目录
git clone https://github.com/1m01m0/image-vision-bridge ~/.claude/skills/image-vision-bridge
```

**DeepSeek Harness（DSH）**：DSH 自动扫描 `~/.agents/skills/` 与 `~/.dsh/skills/`（热刷新，无需重启）：

```bash
git clone https://github.com/1m01m0/image-vision-bridge ~/.agents/skills/image-vision-bridge
```

## 视觉 API 配置（可选，用于“看图说话”）

本地引擎免费且不上传数据；需要语义级理解（照片、复杂图表）时，配置一个 OpenAI 兼容的视觉模型：

```bash
# 创建 ~/.dsh/vision.env（权限 600），填写：
DSH_VISION_API_KEY=sk-你的密钥
DSH_VISION_API_BASE=https://open.bigmodel.cn/api/paas/v4   # 智谱 GLM（glm-4v-flash 免费）
DSH_VISION_MODEL=glm-4v-flash
```

常用供应商：智谱 GLM（免费）、阿里百炼 Qwen-VL、硅基流动 DeepSeek-VL2、Moonshot、OpenAI、OpenRouter（详见 `references/engine-notes.md`）。

## 隐私

- 本地引擎（OCR/检测/分类/颜色）全部在本机运行，不上传任何数据。
- 仅调用视觉 API 时图片会发送给第三方服务——skill 会先征得用户同意。

## License

MIT
