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
    ../../modules/apps/firefox.nix
    ../../modules/apps/onepassword.nix
    ../../modules/apps/discord.nix
    ../../modules/apps/signal.nix
    ../../modules/apps/spotify.nix
    ../../modules/gaming/steam.nix
    ../../modules/development/claude-code.nix
    ../../modules/development/docker.nix
    ../../modules/development/vscode.nix
  ];

  networking.hostName = "battlestation";
  system.stateVersion = "25.11";

  lansing.desktop.keyboardLayout = "iso";
}
