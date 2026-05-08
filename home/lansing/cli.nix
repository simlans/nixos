{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    eza
    jq
    yq-go
    tree
    htop
    file
    dnsutils
  ];
}
