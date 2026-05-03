{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    fuzzel
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
