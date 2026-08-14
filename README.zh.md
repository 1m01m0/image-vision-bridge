# Image Vision Bridge

[English](README.md) | 中文

**Image Vision Bridge** 是一个 [Agent Skill](https://agentskills.io/specification)，让纯文本大模型（DeepSeek 等）也能“看见”图片。

DeepSeek 等纯文本模型无法直接读取图片。本 skill 用**双轨方案**把图片内容转换成模型可处理的文本：

1. **本地引擎（默认——免费、隐私、零依赖）**——macOS Vision 多语言 OCR、二维码/条形码解码、人脸检测、场景分类、主色调与元数据提取。全程不出本机。
2. **第三方多模态模型（可选，按需）**——通过 OpenAI 兼容接口接入 GLM-4V、Qwen-VL、GPT-4o、DeepSeek-VL2 等视觉大模型，真正“看懂”照片、复杂图表和手绘草图。

## 定位与适用场景

这是一个 **Agent Skill / 显式图片工具箱**。它适合在用户明确指定图片来源和处理任务后读取图片；它不是 DeepSeek Harness 的聊天附件路由插件。

| 需求 | 应使用 |
| --- | --- |
| 对明确的本地文件做 OCR、二维码解码、颜色或元数据提取 | **`image-vision-bridge`** |
| GUI 无法附图，需要用户明确授权读取剪贴板或上传到本机页面 | **`image-vision-bridge`** |
| 在没有图片路由能力的文本 Agent 中，手动调用视觉 API 分析指定文件 | **`image-vision-bridge`** |
| 在 DeepSeek Harness 中选择 DeepSeek，并直接从聊天框发送图片 | [`dsh-image-router`](https://github.com/1m01m0/dsh-image-router) |
| 让 MiniMax-M3 等模型自动看图，再由 DeepSeek 回答 | `dsh-image-router` |
| 当前模型本身已经支持图片输入 | 通常两者都不需要 |

### 与 dsh-image-router 的关系

- `dsh-image-router` 是 **Harness 自动编排层**：处理聊天附件，调用配置的视觉模型一次，再把文字描述交给 DeepSeek。
- `image-vision-bridge` 是 **显式工具层**：处理已知路径、剪贴板或本地上传页中的图片，擅长 OCR、扫码与图片信息提取。
- 两者可以同时安装，但不要用本 Skill 重新寻找或二次分析已经由 `dsh-image-router` 处理的同一张聊天附件。
- 如需在 Harness 中调用本 Skill，建议新开一个没有图片附件的会话，明确给出本地文件路径与任务，例如：“仅在本机对 `/path/to/a.png` 做 OCR”。

### 不适用与安全边界

- 不要为了寻找一张不确定的图片而扫描工作区、下载目录、桌面、临时目录或附件目录。
- 不要把“最近修改的图片”当作用户所指的图片；路径不明确时应先让用户确认。
- 不要用它识别真实人物身份、联网反查人物，或绕过视觉服务的安全限制。
- 调用第三方视觉 API 前应明确告知图片将离开本机，并取得用户对该次发送的同意。
- 如果只要求本地处理，必须只使用本地 OCR、扫码、分类、颜色和元数据工具。

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

> 如果你的目标是在选择 DeepSeek 时直接发送聊天图片，请安装 [`dsh-image-router`](https://github.com/1m01m0/dsh-image-router)，无需为了这条自动工作流安装本 Skill。只有需要显式本地 OCR、扫码、图片信息或备用上传入口时，才在 dsh 中安装本 Skill。

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
- 读取剪贴板或本地上传页只能在用户明确要求时进行。
- 调用视觉 API 时图片会发送给第三方；每次发送前都应说明目标服务并取得同意。
- 本 Skill 不应主动扫描目录寻找图片，也不应把其他本地文件当作当前附件。

## License

[MIT](LICENSE)
