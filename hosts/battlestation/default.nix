{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/_legacy/apps/firefox.nix
    ../../modules/_legacy/apps/onepassword.nix
    ../../modules/_legacy/apps/vesktop.nix
    ../../modules/_legacy/apps/signal.nix
    ../../modules/_legacy/apps/spotify.nix
    ../../modules/_legacy/apps/obs-studio.nix
    ../../modules/_legacy/apps/opencloud.nix
    ../../modules/_legacy/gaming/steam.nix
    ../../modules/_legacy/gaming/lutris.nix
    ../../modules/_legacy/gaming/sunshine.nix
    ../../modules/_legacy/development/claude-code.nix
    ../../modules/_legacy/development/pi-coding-agent.nix
    ../../modules/_legacy/development/nono.nix
    ../../modules/_legacy/development/ollama.nix
    ../../modules/_legacy/development/docker.nix
    ../../modules/_legacy/development/vscodium.nix
  ];

  networking.hostName = "battlestation";
  system.stateVersion = "25.11";

  # Ollama GPU acceleration on the XFX Radeon RX 9070 XT (RDNA 4, gfx1201).
  # ROCm drives AMD cards; the in-kernel amdgpu handles the card itself
  # (linuxPackages_latest is new enough for RDNA 4). If `journalctl -u ollama`
  # shows a CPU fallback because ROCm doesn't yet recognise gfx1201, force the
  # arch with `services.ollama.rocmOverrideGfx = "12.0.1";` (or set
  # HSA_OVERRIDE_GFX_VERSION via services.ollama.environmentVariables).
  # NB: the card has 16 GB VRAM — the 52 GB qwen3-coder-next only *partially*
  # offloads here (the Mac's 64 GB unified memory fits it far better); models
  # that fit ~14 GB run fully on-GPU and fly.
  services.ollama.acceleration = "rocm";

  lansing.desktop.keyboardLayout = "iso";
  lansing.desktop.niriOutputs = ''
    output "DP-1" {
        mode "3440x1440@100.000"
        scale 1
    }
  '';
}
