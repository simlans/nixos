{ inputs, ... }:
let
  # pi-coding-agent is only in nixos-unstable, not in release-25.11.
  # Upstream ships multiple releases per week, so pulling from unstable
  # keeps us close to the current TUI / provider list. Same pattern as
  # claude-code; see modules/development/claude-code.nix.
  unstableFor = pkgs: import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  flake.modules.nixos.development = { pkgs, ... }: {
    environment.systemPackages = [ (unstableFor pkgs).pi-coding-agent ];
  };
}
