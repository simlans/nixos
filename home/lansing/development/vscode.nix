{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    # `pkgs.vscode-marketplace` is provided by the
    # `nix-vscode-extensions` overlay registered in
    # `modules/development/vscode.nix`. Names are lowercased
    # `publisher.name`, matching the marketplace URL slug.
    profiles.default.extensions = with pkgs.vscode-marketplace; [
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
