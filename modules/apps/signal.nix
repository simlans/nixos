{
  flake.modules.nixos.desktop = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.signal-desktop ];

    host.desktop.niri.appWindowRules = [
      {
        match.app-id = "^signal$";
        openOnWorkspace = "communication";
      }
    ];
  };
}
