{ pkgs, ... }:
{
  home.packages = with pkgs; [
    opentofu
  ];
}
