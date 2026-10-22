#!/usr/bin/env sh
# Generate harness-specific config copies. Canonical agent settings live in AGENTS.md
# and .agents/skills; this only wires a harness to the LLM gateway (ADR-0008).
# OpenCode: OpenAI-compatible provider at $LLM_GATEWAY_URL, default model `code`.
set -eu
GW_URL="${LLM_GATEWAY_URL:-http://host.docker.internal:4000}"
mkdir -p "$HOME/.config/opencode"
cat > "$HOME/.config/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llm-gateway": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LLM Gateway",
      "options": {
        "baseURL": "URL_PLACEHOLDER/v1",
        "apiKey": "{env:LLM_GATEWAY_KEY}"
      },
      "models": {
        "fast": {},
        "code": {},
        "reason": {}
      }
    }
  },
  "model": "llm-gateway/code"
}
EOF
sed -i "s|URL_PLACEHOLDER|${GW_URL}|" "$HOME/.config/opencode/opencode.json"
echo "opencode config -> $HOME/.config/opencode/opencode.json (baseURL: ${GW_URL}/v1, apiKey from env)"
