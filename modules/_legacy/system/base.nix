{ pkgs, ... }:
{
  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "de_DE.UTF-8/UTF-8"
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    # Binary cache for Noctalia + Quickshell — without it, every shell
    # update recompiles Quickshell and its Qt deps from source.
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  nixpkgs.config.allowUnfree = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
    tree
    file
    pciutils
    usbutils
    smartmontools
  ];

  programs.zsh.enable = true;
}
