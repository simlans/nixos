{ inputs, ... }:
let
  # nono is only in nixos-unstable. On Linux it sandboxes via Landlock LSM
  # (kernel >= 5.13), which our linuxPackages_latest comfortably exceeds.
  # Installed system-wide so non-interactive uses (services, scripts) can
  # also sandbox if we wire it up later; the user-facing `spi` wrapper that
  # actually consumes nono lives in modules/development/pi-coding-agent.nix.
  unstableFor = pkgs: import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  flake.modules.nixos.development = { pkgs, ... }: {
    environment.systemPackages = [ (unstableFor pkgs).nono ];
  };
}
