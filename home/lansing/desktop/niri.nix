{ pkgs, ... }:
let
  wallpaper = "${pkgs.nixos-artwork.wallpapers.simple-blue}/share/backgrounds/nixos/nix-wallpaper-simple-blue.png";
in
{
  xdg.configFile."niri/config.kdl".text = builtins.replaceStrings
    [ "@WALLPAPER@" ]
    [ wallpaper ]
    (builtins.readFile ./niri.kdl);

  home.packages = with pkgs; [
    swaybg
  ];
}
