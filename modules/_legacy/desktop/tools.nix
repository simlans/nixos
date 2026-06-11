{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    mako
    wl-clipboard
    grim
    slurp
    brightnessctl
    pamixer
    playerctl
    libnotify
  ];
}
