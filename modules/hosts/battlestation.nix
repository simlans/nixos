# battlestation — desktop (AMD Ryzen 7 9800X3D, RX 9070 XT, ultrawide).
{ config, inputs, ... }:
{
  flake.nixosConfigurations.battlestation = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with config.flake.modules.nixos; [
      base
      desktop
      development
      gaming
      obs-studio
      sunshine
      user-lansing
      ../../hosts/battlestation/hardware-configuration.nix
      ../../disko/battlestation.nix
      ({ pkgs, ... }: {
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
        services.ollama.package = pkgs.ollama-rocm;

        lansing.desktop.keyboardLayout = "iso";
        lansing.desktop.niriOutputs = ''
          output "DP-1" {
              mode "3440x1440@100.000"
              scale 1
          }
        '';
      })
    ];
  };
}
