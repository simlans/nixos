{ pkgs, ... }:
{
  home.username = "lansing";
  home.homeDirectory = "/home/lansing";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "simlans";
      email = "55317770+simlans@users.noreply.github.com";
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    eza
    jq
    fzf
  ];
}
