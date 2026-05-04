{ lib, inputs, ... }:
{
  # Pulled in only by laptop hosts. Bundles Framework 13 Pro / Intel
  # Core Ultra Series 3 (Panther Lake) defaults from nixos-hardware
  # plus laptop-only services (fingerprint, fwupd, thermald, lid
  # behaviour). If the actual silicon turns out to be Arrow Lake H
  # (Series 2) instead, swap the import for the generic
  # `framework` + `common-cpu-intel` + `common-pc-laptop` modules.
  imports = [
    inputs.nixos-hardware.nixosModules.framework-intel-core-ultra-series3
  ];

  # nixos-hardware's common-pc-laptop (transitively imported) flips
  # services.tlp.enable on. We already run power-profiles-daemon
  # (modules/desktop/power.nix) which TLP refuses to coexist with —
  # force TLP off so ppd stays the single power manager.
  services.tlp.enable = lib.mkForce false;

  # Goodix fingerprint reader. PAM hookups for login + sudo so the
  # reader actually unlocks something; swaylock/gtklock can be added
  # later if a screen-locker is wired up.
  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;

  # Framework distributes BIOS + EC firmware via LVFS.
  services.fwupd.enable = true;

  # Intel-specific thermal daemon. Harmless if nixos-hardware already
  # sets it, lib.mkDefault keeps overrides cheap.
  services.thermald.enable = lib.mkDefault true;

  # Don't suspend when the lid closes while plugged in — sensible for
  # docked-laptop usage. NixOS 25.11 migrated logind options to the
  # `settings` map (mirroring the upstream `[Login]` ini section).
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
}
