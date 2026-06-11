{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/_legacy/gaming/steam.nix
    ../../modules/_legacy/gaming/lutris.nix
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

  # Pin the comms workspace to the laptop panel so Slack/Vesktop
  # always land there even when an external monitor is plugged in.
  lansing.desktop.niri.workspaceOutputs = {
    communication = "eDP-1";
  };
}
