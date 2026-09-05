# Image Vision Bridge

[English](README.md) | 简体中文

一个 Agent Skill 和命令行图像工具箱，将指定图片转为文字信息：OCR、条码内容、人脸数量、场景标签、图像元数据，以及近似主色。局部提取不足时，可选用视觉 API 获取更丰富的描述。

本地流程主要面向 **macOS**，通过 JXA（JavaScript for Automation）调用 Apple Vision，适合文本模型代理，也适合明确需要 OCR 或结构化图片信息的任务。

## 快速开始：本地处理

需要支持相应 Vision API 的 macOS、`osascript`、Bash 和 Python 3。主色分析和首选图片归一化流程需要 Pillow；OCR 归一化可以回退到 macOS 的 `sips`。安装了英文语言数据的 Tesseract 可作为可选 OCR 后备引擎。

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

上述命令只处理指定的本地图片，不调用视觉 API。OCR 默认语言是简体中文和美式英语，可传入逗号分隔的 Vision 语言名称：

```bash
bash scripts/ocr.sh /absolute/path/to/image.png 'zh-Hans,en-US'
```

结果以文本输出。OCR 准确率受分辨率、版式、语言与引擎影响；人脸检测只报告数量，不识别身份；场景标签属于粗粒度分类，不等同于详细语义理解。

## 安装为 Agent Skill

通过 `skills` CLI 安装，需要 Node.js / npm 和网络：

```bash
npx skills add 1m01m0/image-vision-bridge
```

也可将克隆目录放入所用代理支持的 Skill 目录，保留 [SKILL.md](SKILL.md) 与脚本的相对位置。例如 Claude Code 可使用 `~/.claude/skills/image-vision-bridge`；其他代理请核对其实际发现路径。

向代理提供确定的文件路径与操作：

```text
使用 image-vision-bridge 对 /absolute/path/to/receipt.png 做纯本地 OCR，
提取可见文字，并标记无法确定的字符。
```

Skill 不应扫描 Downloads、Desktop、工作区、临时目录或附件目录来猜测目标图片。路径不明确时，应请用户提供。

## 工具入口

| 任务 | 命令 |
| --- | --- |
| OCR | `bash scripts/ocr.sh IMAGE [LANGUAGES]` |
| 二维码/条码、人脸数量、场景分类 | `osascript -l JavaScript scripts/vision-detect.jxa IMAGE` |
| 元数据、主色、亮度 | `bash scripts/image-info.sh IMAGE` |
| 明确请求后保存当前剪贴板图片 | `bash scripts/clipboard-image.sh /absolute/path/to/output.png` |
| 可选远程视觉描述 | `bash scripts/vision-api.sh IMAGE [PROMPT] [MAX_TOKENS]` |
| 实验性本地上传助手 | `python3 scripts/upload-server.py [PORT] [OUTDIR]` |

剪贴板读取必须来自用户明确请求，并依赖 macOS 剪贴板访问。脚本写入给定的输出路径；使用新文件名以保留已有文件。

### 与 dsh-image-router 的关系

[`dsh-image-router`](https://github.com/1m01m0/dsh-image-router) 负责 DeepSeek Harness 的聊天图片附件路由；Image Vision Bridge 负责明确指定路径、剪贴板或手动上传后的图像处理。二者可共存，但代理不应再次寻找或分析已由路由插件处理过的同一附件。

在 Harness 中使用此 Skill 时，优先在不含图片附件的对话中提供本地路径和具体任务。模型原生支持图片时，直接使用附件功能可能就足够。

## 可选视觉 API

`vision-api.sh` 会把图片和提示词发送给配置的第三方服务。**调用前必须说明目标服务，并获得用户对该次传输的同意。** 脚本本身没有确认提示；用户要求纯本地处理时，不应运行它。

接口必须兼容 `/chat/completions`，并接受图片 data URL。支持以下配置：

| 变量 | 默认值或含义 |
| --- | --- |
| `DSH_VISION_API_KEY` | 必填 API 密钥。 |
| `DSH_VISION_API_BASE` | `https://api.openai.com/v1`，不要附加 `/chat/completions`。 |
| `DSH_VISION_MODEL` | `gpt-4o-mini`，应选择服务支持的视觉模型。 |
| `DSH_VISION_ENV_FILE` | `~/.dsh/vision.env`，可选配置文件路径。 |

默认模型只是脚本中的配置值，不保证服务当前可用或账户拥有访问权限。配置文件会被作为 **Shell 代码执行**，其中的赋值会覆盖已有环境变量。只能使用可信配置文件，应限制权限，且不要提交或共享其内容。

安全配置密钥并获得用户授权后，可运行：

```bash
bash scripts/vision-api.sh /absolute/path/to/diagram.png \
  '解释组件与箭头关系，标记无法辨认的标签。' 1024
```

脚本将原图转为 base64 后发送，不缩放图片；curl 超时为 120 秒，默认最大输出为 1,024 tokens。还需要 `curl`、`file`、`base64` 和 Python 3。大图或不支持的格式可能超过服务限制；部分服务错误仅显示在文本中，退出码仍可能为 0，应同时检查输出内容。

## 实验性上传助手

`upload-server.py` 绑定 `127.0.0.1`，默认端口为 8765，默认保存目录为 `/tmp/vision-uploads`。它没有认证和上传大小限制，并直接将收到的字节保存为 `.png` 文件名，不转换实际图片格式。使用后按 Ctrl+C 停止服务，并按需删除上传文件。

当前页面的粘贴/拖放处理函数误把事件类型字符串当作事件对象，因此浏览器上传流程可能无法提交图片。修复前请使用明确文件路径或剪贴板脚本。这个助手是可选组件，OCR 和检测不依赖它。

## 限制、隐私与排查

- Apple Vision OCR、条码、人脸、场景分类及剪贴板功能依赖 macOS。Linux/Windows 尚无完整支持；Pillow/Tesseract 回退流程不能提供全部能力。
- OCR 归一化使用图片第一帧。Pillow 流程转为 RGB，并将宽度限制到 4,096 像素；`sips` 回退没有同样的缩放逻辑。具体格式支持取决于解码器。
- 只有 Vision 出错时才尝试英文 Tesseract；Vision 成功但未检出文字，或文字不准确时，不会触发第二轮识别。
- 出现 `No module named PIL` 时，应在脚本使用的 Python 环境中安装 Pillow；系统缺少 Vision 能力或图片格式不受支持，也可能导致处理失败。
- 本地命令不发送模型请求。但代理读取提取结果后，这些文字会进入代理对话，适用对应服务的数据处理方式。
- 不识别真实人物身份，不联网寻找人物身份，不绕过服务限制。OCR 与模型描述应保留不确定性。

## 开发与反馈

实现入口见 [SKILL.md](SKILL.md)、[scripts](scripts) 和 [引擎说明](references/engine-notes.md)。仓库没有自动化测试套件。修改后应用非敏感测试图片验证 OCR、条码、不支持的格式和缺失依赖；没有明确请求时，不读取剪贴板或调用远程 API。

[反馈问题](https://github.com/1m01m0/image-vision-bridge/issues) 时请提供 macOS/Python 版本、命令和脱敏错误；只分享有权公开的图片，不附带密钥。

## 许可证

[MIT](LICENSE)，Copyright © 2026 1m01m0。
