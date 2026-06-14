# workstation — Framework 13 Pro laptop (Intel Core Ultra 7 358H).
{ config, inputs, ... }:
{
  flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with config.flake.modules.nixos; [
      base
      desktop
      development
      gaming
      laptop
      slack
      user-lansing
      ../../hosts/workstation/hardware-configuration.nix
      ../../disko/workstation.nix
      # Framework 13 Pro / Intel Core Ultra Series 3 (Panther Lake)
      # defaults from nixos-hardware. If the actual silicon turns out to
      # be Arrow Lake H (Series 2) instead, swap the import for the
      # generic `framework` + `common-cpu-intel` + `common-pc-laptop`
      # modules.
      inputs.nixos-hardware.nixosModules.framework-intel-core-ultra-series3
      ({ lib, ... }: {
        networking.hostName = "workstation";
        system.stateVersion = "25.11";

        # Goodix fingerprint reader. PAM hookups for login + sudo so the
        # reader actually unlocks something; swaylock/gtklock can be
        # added later if a screen-locker is wired up.
        services.fprintd.enable = true;
        security.pam.services.login.fprintAuth = true;
        security.pam.services.sudo.fprintAuth = true;

        # Intel-specific thermal daemon. Harmless if nixos-hardware
        # already sets it, lib.mkDefault keeps overrides cheap.
        services.thermald.enable = lib.mkDefault true;

        host.desktop.keyboardLayout = "ansi";

        # eDP-1 is the Framework 13 Pro internal panel (2.8K @ 120 Hz).
        # `niri msg outputs` post-install will report the exact mode
        # string; correct here if it differs.
        host.desktop.niriOutputs = ''
          output "eDP-1" {
              mode "2880x1920@120.000"
              scale 1.5
          }
        '';

        # Pin the comms workspace to the laptop panel so Slack/Vesktop
        # always land there even when an external monitor is plugged in.
        host.desktop.niri.workspaceOutputs = {
          communication = "eDP-1";
        };
      })
    ];
  };
}
