{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    alacritty
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
