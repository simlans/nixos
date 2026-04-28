{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/base.nix
    ../../modules/system/boot.nix
    ../../modules/system/network.nix
    ../../modules/system/users.nix
    ../../modules/desktop/niri.nix
    ../../modules/desktop/apps.nix
  ];

  networking.hostName = "battlestation";
  system.stateVersion = "25.11";
}
