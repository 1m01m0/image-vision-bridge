#!/bin/bash
# vision-api.sh — describe an image with an OpenAI-compatible vision API.
# Use only when local engines are not enough AND the user has provided a key.
#
# Env (ask the user to set these):
#   DSH_VISION_API_KEY   required
#   DSH_VISION_API_BASE  default https://api.openai.com/v1
#                        e.g. GLM: https://open.bigmodel.cn/api/paas/v4
#                             Qwen: https://dashscope.aliyuncs.com/compatible-mode/v1
#                             Moonshot: https://api.moonshot.cn/v1
#                             SiliconFlow: https://api.siliconflow.cn/v1
#   DSH_VISION_MODEL     default gpt-4o-mini (e.g. glm-4v-flash, qwen-vl-plus,
#                        moonshot-v1-8k-vision-preview, deepseek-ai/deepseek-vl2)
#
# Configuration (priority: ~/.dsh/vision.env file first, then environment variables):
set -uo pipefail

# Load persistent config if present (e.g. ~/.dsh/vision.env):
#   DSH_VISION_API_KEY=sk-xxx
#   DSH_VISION_API_BASE=https://open.bigmodel.cn/api/paas/v4
#   DSH_VISION_MODEL=glm-4v-flash
VISION_ENV="${DSH_VISION_ENV_FILE:-$HOME/.dsh/vision.env}"
if [ -f "$VISION_ENV" ]; then
  set -a
  . "$VISION_ENV"
  set +a
fi

IMG="$1"
PROMPT="${2:-Describe this image in detail: all visible text, people, objects, layout, colors, and any notable details. Answer in the language the user is using.}"
MAX="${3:-1024}"
KEY="${DSH_VISION_API_KEY:-}"
BASE="${DSH_VISION_API_BASE:-https://api.openai.com/v1}"
MODEL="${DSH_VISION_MODEL:-gpt-4o-mini}"

[ -n "$IMG" ] && [ -f "$IMG" ] || { echo "ERROR: no such file: $IMG"; exit 2; }
if [ -z "$KEY" ]; then
  echo "ERROR: DSH_VISION_API_KEY is not set."
  echo "Local engines (Vision OCR/detection/classification) are free and on-device; use them first."
  echo "Only if the user wants richer understanding of a photo or complex diagram, ask for a key, e.g.:"
  echo '  export DSH_VISION_API_KEY=sk-xxx DSH_VISION_API_BASE=https://open.bigmodel.cn/api/paas/v4 DSH_VISION_MODEL=glm-4v-flash'
  exit 3
fi
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found"; exit 4; }

MIME=$(file -b --mime-type "$IMG")
B64=$(base64 < "$IMG")
PROMPT_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$PROMPT")

echo "## Vision API ($MODEL @ $BASE)"
RESP="$(curl -sS --max-time 120 "${BASE%/}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d "{\"model\":\"$MODEL\",\"max_tokens\":$MAX,\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":$PROMPT_JSON},{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:$MIME;base64,$B64\"}}]}]}")"
if [ -z "$RESP" ]; then
  echo "ERROR: empty response from $BASE (check DSH_VISION_API_BASE / network)"
  exit 5
fi
python3 - "$RESP" <<'PYEOF'
import json, sys
try:
    data = json.loads(sys.argv[1])
    if 'choices' in data and data['choices']:
        print(data['choices'][0]['message']['content'])
    else:
        print('ERROR response from provider:')
        print(json.dumps(data, ensure_ascii=False)[:2000])
except Exception as e:
    print('ERROR: could not parse provider response: %s' % e)
    print(sys.argv[1][:2000])
PYEOF
