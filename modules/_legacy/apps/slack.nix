{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.slack ];

  lansing.desktop.niri.appWindowRules = [
    {
      match.app-id = "^Slack$";
      openOnWorkspace = "communication";
    }
  ];
}
