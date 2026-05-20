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
    ../../modules/gaming/steam.nix
    ../../modules/gaming/lutris.nix
    ../../modules/gaming/sunshine.nix
    ../../modules/development/claude-code.nix
    ../../modules/development/docker.nix
    ../../modules/development/vscode.nix
  ];

  networking.hostName = "battlestation";
  system.stateVersion = "25.11";

  lansing.desktop.keyboardLayout = "iso";
  lansing.desktop.niriOutputs = ''
    output "DP-1" {
        mode "3440x1440@100.000"
        scale 1
    }
  '';
}
