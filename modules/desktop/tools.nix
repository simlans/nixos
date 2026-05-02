{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    fuzzel
    waybar
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
