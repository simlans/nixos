{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.signal-desktop ];

  lansing.desktop.niri.appWindowRules = [
    {
      match.app-id = "^signal$";
      openOnWorkspace = "communication";
    }
  ];
}
