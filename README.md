# claudev
Claude Code on a local Qwen3.5-9B. macOS (llama.cpp) and Linux/DGX Spark (Ollama, CUDA).

```sh
curl -fsSL https://raw.githubusercontent.com/nikola43/claudev/main/install.sh | sh
claudev
```
Installs `claudev` into `/usr/local/bin` for all users (asks for sudo once). First run downloads a ~7 GB model. Override with `CLAUDEV_MODEL` / `CLAUDEV_HOST`.
