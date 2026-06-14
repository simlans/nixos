{
  flake.modules.nixos.desktop = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.vesktop ];

    host.desktop.niri.appWindowRules = [
      {
        match.app-id = "^vesktop$";
        openOnWorkspace = "communication";
      }
    ];
  };
}
