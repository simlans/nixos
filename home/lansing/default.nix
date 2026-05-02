{ pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./onepassword.nix
    ./shell
    ./development
    ./desktop
  ];

  home.username = "lansing";
  home.homeDirectory = "/home/lansing";
  home.stateVersion = "25.11";

  home.pointerCursor = {
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 20;
    gtk.enable = true;
    x11.enable = true;
  };

  programs.home-manager.enable = true;
}
