{ pkgs, inputs, ... }:
let
  # claude-code on the 25.11 channel lags ~30 patches behind upstream and
  # ships without the newest model IDs (e.g. Opus 4.7). Pull it from
  # nixos-unstable instead — see flake.nix `nixpkgs-unstable` input.
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  environment.systemPackages = [ unstable.claude-code ];
}
