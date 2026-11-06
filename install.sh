#!/bin/sh
# claudev installer — Claude Code on a local Qwen3.5-9B.
# macOS: llama.cpp (brew).  Linux (incl. DGX Spark / CUDA): Ollama.
# Usage: curl -fsSL https://raw.githubusercontent.com/nikola43/claudev/main/install.sh | sh
set -e
HF_REPO="DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF"
MODEL_FILE="Qwen3.5-9B-The-Defiant-Fable-Uncnr-Heretic-NEO-MAX-MTP-Q4_K_M.gguf"
CTX=49152

command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

if [ "$(uname)" = "Darwin" ]; then
  BIN="${BIN:-/opt/homebrew/bin}"
  command -v brew >/dev/null || { echo "install Homebrew first: https://brew.sh"; exit 1; }
  command -v llama-server >/dev/null || brew install llama.cpp
  MODEL_DIR="$HOME/.lmstudio/models/local/Qwen3.5-9B-Defiant-Fable-Heretic-NEO-MAX"
  mkdir -p "$MODEL_DIR" "$HOME/.claudev"
  # ponytail: Qwen template rejects Claude Code's message layout; patched copy relaxes two checks
  [ -f "$HOME/.claudev/qwen9b.jinja" ] || curl -fsSL -o "$HOME/.claudev/qwen9b.jinja" https://raw.githubusercontent.com/nikola43/claudev/main/qwen9b.jinja
  [ -f "$MODEL_DIR/$MODEL_FILE" ] || curl -L --progress-bar -C - -o "$MODEL_DIR/$MODEL_FILE" "https://huggingface.co/$HF_REPO/resolve/main/$MODEL_FILE"
  cat > "$BIN/qwen9b" <<EOS
#!/bin/sh
exec llama-server -m "$MODEL_DIR/$MODEL_FILE" --alias qwen9b --host 127.0.0.1 --port 8081 \\
  -c $CTX -ngl 99 -fa on -ctk q8_0 -ctv q8_0 -b 2048 -ub 1024 -t 8 --mlock --jinja \\
  --chat-template-file "\$HOME/.claudev/qwen9b.jinja" "\$@"
EOS
  chmod +x "$BIN/qwen9b"
  HOST=http://127.0.0.1:8081; MODEL=qwen9b; START='nohup qwen9b >/tmp/qwen9b.log 2>&1 &'
else
  BIN="${BIN:-$HOME/.local/bin}"; mkdir -p "$BIN"
  command -v ollama >/dev/null || curl -fsSL https://ollama.com/install.sh | sh
  # ponytail: ollama defaults to a 4k context, far too small for Claude Code
  if command -v systemctl >/dev/null && systemctl is-enabled ollama >/dev/null 2>&1; then
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    printf '[Service]\nEnvironment=OLLAMA_CONTEXT_LENGTH=%s\n' "$CTX" | sudo tee /etc/systemd/system/ollama.service.d/ctx.conf >/dev/null
    sudo systemctl daemon-reload && sudo systemctl restart ollama
  fi
  MODEL="hf.co/$HF_REPO:Q4_K_M"
  pgrep -x ollama >/dev/null || { OLLAMA_CONTEXT_LENGTH=$CTX nohup ollama serve >/tmp/ollama.log 2>&1 & sleep 3; }
  ollama pull "$MODEL"
  HOST=http://127.0.0.1:11434; START="OLLAMA_CONTEXT_LENGTH=$CTX nohup ollama serve >/tmp/ollama.log 2>&1 &"
fi

cat > "$BIN/claudev" <<EOS
#!/bin/sh
# claudev — Claude Code on a local Qwen3.5-9B.
set -e
export PATH="\$HOME/.local/bin:\$PATH"
HOST="\${CLAUDEV_HOST:-$HOST}"
MODEL="\${CLAUDEV_MODEL:-$MODEL}"
if ! curl -sf "\$HOST" >/dev/null 2>&1; then
  $START
  for _ in \$(seq 1 120); do curl -sf "\$HOST" >/dev/null 2>&1 && break; sleep 1; done
  curl -sf "\$HOST" >/dev/null || { echo "local model server failed to start"; exit 1; }
fi
CLAUDE_CONFIG_DIR="\$HOME/.claudev" \\
ANTHROPIC_BASE_URL="\$HOST" ANTHROPIC_AUTH_TOKEN=local ANTHROPIC_API_KEY= \\
ANTHROPIC_MODEL="\$MODEL" ANTHROPIC_DEFAULT_SONNET_MODEL="\$MODEL" \\
ANTHROPIC_DEFAULT_OPUS_MODEL="\$MODEL" ANTHROPIC_DEFAULT_HAIKU_MODEL="\$MODEL" \\
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \\
exec claude --model "\$MODEL" "\$@"
EOS
chmod +x "$BIN/claudev"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "add to your shell rc:  export PATH=\"$BIN:\$PATH\"";; esac
echo "done. run: claudev"
