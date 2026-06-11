{ pkgs, ... }:
{
  programs.obs-studio.enable = true;
  environment.systemPackages = [ pkgs.v4l-utils ];
}
