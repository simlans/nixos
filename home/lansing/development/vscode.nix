{ pkgs, inputs, ... }:
let
  # vscode on the 25.11 channel ships 1.106.2, which is too old for
  # several extensions (they require ^1.107 / ^1.110). Pull it from
  # nixos-unstable instead — same pattern as claude-code.
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  programs.vscode = {
    enable = true;
    package = unstable.vscode;

    profiles.default.userSettings = {
      "files.autoSave" = "afterDelay";
      "git.confirmSync" = false;
      "git.autofetch" = true;
    };

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
      kdl-org.kdl
    ];
  };
}
