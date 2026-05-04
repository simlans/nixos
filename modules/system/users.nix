{ lib, pkgs, ... }:
{
  users.mutableUsers = true;
  users.defaultUserShell = pkgs.zsh;

  users.users.lansing = {
    isNormalUser = true;
    # Fallback when /etc/nixos/local/full-name is missing. The real name
    # is per-machine private (kept out of this public repo) and applied
    # over the top of this default by the activation script below.
    description = "lansing";
    # No initialPassword: the bootstrap password is set via
    # `nixos-enter --root /mnt -c 'passwd lansing'` after disko-install
    # finishes and before the first reboot, so no plaintext or hash from
    # this repo ever lands in the world-readable Nix store.
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "audio"
      "docker"
    ];
  };

  # NixOS regenerates /etc/passwd from the declarative spec on every
  # rebuild, so a manual `chfn` would get clobbered (see
  # nixos/modules/config/update-users-groups.pl: `description` is taken
  # from the JSON spec, not from the existing /etc/passwd row, and
  # `mutableUsers = true` only protects the password field). This script
  # runs after the `users` activation and writes the GECOS field back
  # from /etc/nixos/local/full-name when that file exists. The file is
  # seeded once per machine via `nix run .#init-account` at install
  # time (see flake.nix and README); to change the value later, just
  # edit the file directly and rebuild. It lives outside the Nix store
  # so it survives rebuilds without ever entering git.
  system.activationScripts.applyLocalFullName = lib.stringAfter [ "users" ] ''
    if [ -r /etc/nixos/local/full-name ]; then
      desired=$(${pkgs.coreutils}/bin/head -n 1 /etc/nixos/local/full-name)
      if [ -n "$desired" ]; then
        current=$(${pkgs.coreutils}/bin/getent passwd lansing \
          | ${pkgs.coreutils}/bin/cut -d: -f5)
        if [ "$desired" != "$current" ]; then
          ${pkgs.shadow}/bin/usermod -c "$desired" lansing
        fi
      fi
    fi
  '';
}
