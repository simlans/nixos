{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kubectl
    k9s
    fluxcd
    talosctl
  ];

  xdg.configFile = {
    "k9s/config.yaml".source = ./k9s-config.yaml;
    "k9s/skins/transparent.yaml".source = ./transparent.yaml;
  };
}
