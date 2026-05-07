{ ... }:
{
  imports = [
    ./claude-code.nix
    ./git.nix
    ./golang.nix
    ./kubernetes
    ./neovim
    ./opentofu.nix
    ./vscode.nix
  ];
}
