{
  flake.modules.nixos.desktop = {
    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;
  };
}
