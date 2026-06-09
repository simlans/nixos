{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/base.nix
    ../../modules/system/boot.nix
    ../../modules/system/network.nix
    ../../modules/system/users.nix
    ../../modules/system/openssh.nix
    ../../modules/system/sops.nix
    ../../modules/system/tailscale.nix
    ../../modules/desktop/niri.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/audio.nix
    ../../modules/desktop/power.nix
    ../../modules/desktop/tools.nix
    ../../modules/desktop/keyring.nix
    ../../modules/apps/firefox.nix
    ../../modules/apps/onepassword.nix
    ../../modules/apps/vesktop.nix
    ../../modules/apps/signal.nix
    ../../modules/apps/spotify.nix
    ../../modules/apps/obs-studio.nix
    ../../modules/apps/opencloud.nix
    ../../modules/gaming/steam.nix
    ../../modules/gaming/lutris.nix
    ../../modules/gaming/sunshine.nix
    ../../modules/development/claude-code.nix
    ../../modules/development/pi-coding-agent.nix
    ../../modules/development/nono.nix
    ../../modules/development/ollama.nix
    ../../modules/development/docker.nix
    ../../modules/development/vscodium.nix
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
