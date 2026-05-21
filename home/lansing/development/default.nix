{ ... }:
{
  imports = [
    ./claude-code.nix
    ./pi-coding-agent.nix
    ./git.nix
    ./golang.nix
    ./kubernetes
    ./neovim
    ./opentofu.nix
    ./vscodium.nix
  ];
}
