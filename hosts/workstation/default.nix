{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/base.nix
    ../../modules/system/boot.nix
    ../../modules/system/network.nix
    ../../modules/system/users.nix
    ../../modules/system/openssh.nix
    ../../modules/system/tailscale.nix
    ../../modules/desktop/niri.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/audio.nix
    ../../modules/desktop/power.nix
    ../../modules/desktop/tools.nix
    ../../modules/desktop/keyring.nix
    ../../modules/desktop/laptop.nix
    ../../modules/apps/firefox.nix
    ../../modules/apps/onepassword.nix
    ../../modules/apps/discord.nix
    ../../modules/apps/signal.nix
    ../../modules/apps/spotify.nix
    ../../modules/apps/slack.nix
    ../../modules/gaming/steam.nix
    ../../modules/development/claude-code.nix
    ../../modules/development/docker.nix
    ../../modules/development/vscode.nix
  ];

  networking.hostName = "workstation";
  system.stateVersion = "25.11";

  lansing.desktop.keyboardLayout = "ansi";

  # eDP-1 is the Framework 13 Pro internal panel (2.8K @ 120 Hz).
  # `niri msg outputs` post-install will report the exact mode
  # string; correct here if it differs.
  lansing.desktop.niriOutputs = ''
    output "eDP-1" {
        mode "2880x1920@120.000"
        scale 1.5
    }
  '';
}
