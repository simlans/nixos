{ pkgs, inputs, ... }:
let
  # Lutris install scripts on lutris.net pin a minimum Lutris version per
  # game; current scripts (e.g. Elder Scrolls Online) require 0.5.22+,
  # but release-25.11 still ships 0.5.19. Pull lutris + umu-launcher
  # from nixos-unstable instead — see flake.nix `nixpkgs-unstable` input.
  # The two packages are bumped together because Lutris 0.5.20+ expects
  # the protonfixes interface that ships in umu-launcher 1.4+.
  #
  # openldap-2.6.13 in nixos-unstable has a flaky check-phase test
  # (test017-syncreplication-refresh; the syncrepl-replication consumer
  # occasionally diverges from the provider before the assertion runs
  # on parallel builders). Lutris's FHS-userenv-rootfs pulls openldap
  # transitively, so the whole rebuild fails when the test races.
  # doCheck = false skips the check phase only — openldap-as-library
  # still builds and installs normally, and we don't run slapd here,
  # so the lost test coverage doesn't matter for our use case.
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
    overlays = [
      (_: prev: {
        openldap = prev.openldap.overrideAttrs (_: {
          doCheck = false;
          doInstallCheck = false;
        });
      })
    ];
  };
in
{
  # Lutris 0.5.20+ defaults to running games via UMU with
  # PROTONPATH=GE-Proton. UMU fetches GE-Proton itself on first use into
  # ~/.local/share/Steam/compatibilitytools.d/, so Proton versions are
  # neither needed nor possible to pin declaratively here.
  #
  # Wine-GE (the standalone Wine build Lutris used pre-2025) is EOL —
  # do NOT add wineWowPackages. UMU runs GE-Proton inside Steam's Linux
  # runtime container outside of Steam itself, which is why nixpkgs
  # ships both lutris and umu-launcher as buildFHSUserEnvBubblewrap
  # derivations (Wine assumes /usr/lib32 etc., supplied by the wrapper).
  # Per-game lutris.net install scripts may still pull a Wine-GE runner
  # into ~/.local/share/lutris/runners/wine/ at runtime — that's user
  # state outside the Nix store; override the runner in the game's
  # Lutris config (Configure → Runner options → Wine version) if a
  # different one is wanted.
  #
  # ProtonUp-Qt is also unnecessary in this stack: UMU manages the
  # GE-Proton lifecycle on its own. Only add it if a Steam-only workflow
  # ever needs manual Proton-version pinning.
  #
  # 32-bit graphics: enabled by modules/gaming/steam.nix.
  environment.systemPackages = [
    unstable.lutris
    unstable.umu-launcher
  ];
}
