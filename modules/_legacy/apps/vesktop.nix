{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.vesktop ];

  lansing.desktop.niri.appWindowRules = [
    {
      match.app-id = "^vesktop$";
      openOnWorkspace = "communication";
    }
  ];
}
