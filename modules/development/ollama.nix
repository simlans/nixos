{ ... }:
{
  # Local Ollama server, backing the Pi coding agent's `ollama` provider
  # (home/lansing/development/pi-coding-agent.nix). Ollama serves an
  # OpenAI-compatible API on 127.0.0.1:11434 by default — exactly the baseUrl
  # that provider points at — so models pulled here (qwen3-coder-next, gemma)
  # show up under Pi's /model and are reachable from `spi`: the nono profile
  # opens that localhost port via `open_port = [ 11434 ]`.
  #
  # Bound to localhost only (Ollama's default host) → no firewall hole, nothing
  # reachable off-box. Matches the rest of this config's posture.
  #
  # Models are managed at RUNTIME, not declared here. `services.ollama.loadModels`
  # could pre-pull on rebuild, but (a) these weigh tens of GB — we keep them off
  # the rebuild path — and (b) each is wrapped in a derived Modelfile tag
  # (`FROM <base>` + `PARAMETER num_ctx <n>`) to lift Ollama's 4096-token default
  # to a real context window, which `loadModels` can't express. So pull + derive
  # by hand, same as the Mac (docs/pi-coding-agent-macos.md):
  #   ollama pull qwen3-coder-next
  #   printf 'FROM qwen3-coder-next\nPARAMETER num_ctx 65536\n' | ollama create qwen3-coder-next-64k -f -
  #
  # Acceleration defaults to CPU here (correct for the Intel Framework laptop /
  # workstation, which has no discrete GPU). On a GPU host, set it per-host in
  # hosts/<name>/default.nix — e.g. battlestation:
  #   services.ollama.acceleration = "rocm";   # AMD GPU
  #   services.ollama.acceleration = "cuda";   # NVIDIA GPU (needs allowUnfree)
  services.ollama.enable = true;
}
