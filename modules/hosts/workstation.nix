# workstation — Framework 13 Pro laptop (Intel Core Ultra 7 358H).
{ config, inputs, ... }:
{
  flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; inherit (inputs) self; };
    modules = [
      config.flake.modules.nixos.base
      config.flake.modules.nixos.desktop
      config.flake.modules.nixos.development
      config.flake.modules.nixos.laptop
      config.flake.modules.nixos.slack
      ../../disko/workstation.nix
      ../../hosts/workstation
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.lansing = import ../../home/lansing;
      }
    ];
  };
}
