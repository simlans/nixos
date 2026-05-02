{ pkgs, inputs, ... }:
let
  # Pulls every extension from the Visual Studio Marketplace via the
  # nix-vscode-extensions flake input. Names are lowercased
  # `publisher.name`, matching the marketplace URL slug.
  marketplace =
    inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default.extensions = with marketplace; [
      anthropic.claude-code
      samuelcolvin.jinjahtml
      tumido.cron-explained
      waderyan.gitblame
      mhutchie.git-graph
      golang.go
      hashicorp.terraform
      ms-kubernetes-tools.vscode-kubernetes-tools
      yzhang.markdown-all-in-one
      yzane.markdown-pdf
      bierner.markdown-mermaid
      antyos.openscad
      leathong.openscad-language-support
      medo64.render-crlf
      svelte.svelte-vscode
      adamhartford.vscode-base64
      jnoortheen.nix-ide
    ];
  };
}
