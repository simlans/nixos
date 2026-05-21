{ pkgs, inputs, ... }:
let
  # vscodium on the 25.11 channel may lag behind extension manifests that
  # require ^1.107 / ^1.110. Pull it from nixos-unstable instead — same
  # pattern as claude-code.
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  # Electron's OSCrypt can't auto-pick a Secret Service backend under
  # niri (XDG_CURRENT_DESKTOP=niri isn't on its known-desktops list), so
  # VSCodium falls back to "basic" text encryption and warns "An OS
  # keyring couldn't be identified …". Forcing the libsecret backend
  # routes it at the gnome-keyring daemon (D-Bus activation set up in
  # modules/desktop/keyring.nix). See microsoft/vscode#187338.
  #
  # VSCodium reads argv.json from .vscode-oss/, not .vscode/.
  home.file.".vscode-oss/argv.json".text = builtins.toJSON {
    "password-store" = "gnome-libsecret";
  };

  programs.vscode = {
    enable = true;
    package = unstable.vscodium;

    profiles.default.userSettings = {
      "files.autoSave" = "afterDelay";
      "git.confirmSync" = false;
      "git.autofetch" = true;
      "editor.fontFamily" = "'JetBrainsMono Nerd Font', monospace";
      "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font";
      "workbench.colorTheme" = "Catppuccin Mocha";
      "workbench.secondarySideBar.defaultVisibility" = "hidden";
      "claudeCode.preferredLocation" = "panel";
    };

    # `pkgs.vscode-marketplace` is provided by the
    # `nix-vscode-extensions` overlay registered in
    # `modules/development/vscodium.nix`. Names are lowercased
    # `publisher.name`, matching the marketplace URL slug. VSCodium
    # doesn't ship a marketplace client at runtime, but Nix-installed
    # extensions are just unpacked into the extensions dir, so the MS
    # marketplace mirror works regardless (Open VSX would miss several
    # of these, e.g. anthropic.claude-code).
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
      catppuccin.catppuccin-vsc
    ];
  };
}
