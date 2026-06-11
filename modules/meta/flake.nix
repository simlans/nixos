# Core wiring for the dendritic layout. Every .nix file under `modules/`
# is auto-imported (via import-tree in flake.nix) as a flake-parts module;
# this one enables the pieces the rest of the tree relies on.
{ inputs, ... }:
{
  # Provides the `flake.modules.<class>.<name>` option (deferredModule):
  # files all over the tree define e.g. `flake.modules.nixos.desktop` and
  # the definitions merge into one module per name. Without this import
  # those definitions would be rejected as unknown options.
  imports = [ inputs.flake-parts.flakeModules.modules ];

  # x86_64-linux: the NixOS hosts. aarch64-darwin: this repo is edited on
  # a Mac — exposing the devShell/checks there lets direnv's `use flake`
  # install the gitleaks pre-commit hook locally.
  systems = [
    "x86_64-linux"
    "aarch64-darwin"
  ];
}
