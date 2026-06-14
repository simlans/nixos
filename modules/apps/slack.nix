# Work chat. workstation only.
{
  flake.modules.nixos.slack = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.slack ];

    host.desktop.niri.appWindowRules = [
      {
        match.app-id = "^Slack$";
        openOnWorkspace = "communication";
      }
    ];
  };
}
