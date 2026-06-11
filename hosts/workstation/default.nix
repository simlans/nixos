{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/_legacy/apps/firefox.nix
    ../../modules/_legacy/apps/onepassword.nix
    ../../modules/_legacy/apps/vesktop.nix
    ../../modules/_legacy/apps/signal.nix
    ../../modules/_legacy/apps/spotify.nix
    ../../modules/_legacy/apps/slack.nix
    ../../modules/_legacy/apps/opencloud.nix
    ../../modules/_legacy/gaming/steam.nix
    ../../modules/_legacy/gaming/lutris.nix
    ../../modules/_legacy/development/claude-code.nix
    ../../modules/_legacy/development/pi-coding-agent.nix
    ../../modules/_legacy/development/nono.nix
    ../../modules/_legacy/development/ollama.nix
    ../../modules/_legacy/development/docker.nix
    ../../modules/_legacy/development/vscodium.nix
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
