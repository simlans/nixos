{ inputs, ... }:
{
  flake.modules.nixos.development = {
    # Register the nix-vscode-extensions overlay on system pkgs so that
    # `pkgs.vscode-marketplace.<publisher>.<name>` is available everywhere
    # (including the home-manager profile, via `useGlobalPkgs = true`).
    #
    # Going through the overlay — instead of consuming the flake's
    # `extensions.<system>` outputs directly — means each extension is
    # built with the system's `nixpkgs.config.allowUnfree = true`. The
    # flake otherwise instantiates its own pkgs with default config,
    # which rejects any extension carrying the marketplace's "unfree"
    # license stamp (i.e. all of them).
    nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];
  };
}
