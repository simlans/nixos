# workstation — Framework 13 Pro laptop (Intel Core Ultra 7 358H).
{ config, inputs, ... }:
{
  flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; inherit (inputs) self; };
    modules = with config.flake.modules.nixos; [
      base
      desktop
      development
      gaming
      laptop
      slack
      ../../hosts/workstation/hardware-configuration.nix
      ../../disko/workstation.nix
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.lansing = import ../../home/lansing;
      }
      {
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
    ];
  };
}
