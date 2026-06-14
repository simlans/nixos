# The `lansing` user as a single aspect: the NixOS account and everything
# account-scoped (groups, SSH keys, sudo, GECOS) plus the home-manager
# identity. A host gets lansing by importing nixos.user-lansing, which also
# registers lansing into my.homeUsers (modules/users/home-manager.nix), so the
# base + role home buckets attach automatically.
{ config, ... }:
let
  hmLansing = config.flake.modules.homeManager.lansing;
in
{
  flake.modules.nixos.user-lansing = { lib, pkgs, ... }: {
    my.homeUsers = [ "lansing" ];

    users.users.lansing = {
      isNormalUser = true;
      # Fallback when /etc/nixos/local/full-name is missing. The real name is
      # per-machine private (kept out of this public repo) and applied over the
      # top of this default by the activation script below.
      description = "lansing";
      # No initialPassword: the bootstrap password is set via
      # `nixos-enter --root /mnt -c 'passwd lansing'` after disko-install
      # finishes and before the first reboot, so no plaintext or hash from this
      # repo ever lands in the world-readable Nix store.
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "input"
        "audio"
        "docker"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFSIDoZWfx6cHP0Tp1xwi6cBnYopSd2YHbFugA7t32KN"
      ];
    };

    # Passwordless `sudo nixos-rebuild` for the primary user. Keeps password
    # prompts on every other sudo invocation — only the rebuild path is
    # whitelisted, so a compromised shell still can't escalate to arbitrary
    # root commands.
    security.sudo.extraRules = [
      {
        users = [ "lansing" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # NixOS regenerates /etc/passwd from the declarative spec on every rebuild,
    # so a manual `chfn` would get clobbered (see
    # nixos/modules/config/update-users-groups.pl: `description` is taken from
    # the JSON spec, not from the existing /etc/passwd row, and
    # `mutableUsers = true` only protects the password field). This script runs
    # after the `users` activation and writes the GECOS field back from
    # /etc/nixos/local/full-name when that file exists. The file is seeded once
    # per machine via `nix run .#init-account` at install time (see
    # modules/meta/bootstrap-apps.nix and README); to change the value later,
    # just edit the file directly and rebuild. It lives outside the Nix store
    # so it survives rebuilds without ever entering git.
    system.activationScripts.applyLocalFullName = lib.stringAfter [ "users" ] ''
      if [ -r /etc/nixos/local/full-name ]; then
        desired=$(${pkgs.coreutils}/bin/head -n 1 /etc/nixos/local/full-name)
        if [ -n "$desired" ]; then
          current=$(${pkgs.getent}/bin/getent passwd lansing \
            | ${pkgs.coreutils}/bin/cut -d: -f5)
          if [ "$desired" != "$current" ]; then
            ${pkgs.shadow}/bin/usermod -c "$desired" lansing
          fi
        fi
      fi
    '';

    home-manager.users.lansing.imports = [ hmLansing ];
  };

  # home-manager identity unique to lansing. Shared home content (cursor,
  # stateVersion, programs.home-manager) lives in modules/users/home-base.nix.
  # username/homeDirectory are set explicitly (rather than relying on the
  # home-manager NixOS module's auto-derivation from the attr name) so this
  # bucket is correct in isolation and safe to copy for a second user.
  flake.modules.homeManager.lansing = {
    home.username = "lansing";
    home.homeDirectory = "/home/lansing";
  };
}
