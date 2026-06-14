# Aspect builder for OS users — a plain function, imported directly by each user
# file (modules/users/<name>.nix) rather than exposed via flake.lib. It must NOT
# be reached through config.flake.*: a user file's module *structure* would then
# depend on the flake-parts config fixpoint that it itself feeds, which is an
# infinite recursion. Living outside modules/ keeps import-tree from loading it
# as a (malformed) flake-parts module, and a direct `import` keeps the result a
# static attrset.
#
# `mkUser { username; … }` returns the whole per-user aspect: the NixOS account
# (groups, SSH keys, sudo, GECOS) plus the home-manager identity, and
# self-registration into my.homeUsers / my.primaryUser. The username lives in
# exactly one place per user and the structure lives here once, so the host
# modules stay decoupled from any specific user.
{ username
, sshKeys ? [ ]
, extraGroups ? [ "wheel" "networkmanager" "video" "input" "audio" "docker" ]
, description ? username
}:
{
  flake.modules.nixos."user-${username}" = { lib, pkgs, ... }: {
    my.homeUsers = [ username ];
    # Single-user hosts derive primaryUser from this; a multi-user host
    # overrides it explicitly (two mkDefaults conflict on purpose — see
    # modules/users/home-manager.nix).
    my.primaryUser = lib.mkDefault username;

    users.users.${username} = {
      isNormalUser = true;
      # Fallback when /etc/nixos/local/full-name-${username} is missing. The
      # real name is per-machine private (kept out of this public repo) and
      # applied over the top of this default by the activation script below.
      inherit description extraGroups;
      # No initialPassword: the bootstrap password is set via
      # `nixos-enter --root /mnt -c 'passwd ${username}'` after disko-install
      # finishes and before the first reboot, so no plaintext or hash from this
      # repo ever lands in the world-readable Nix store.
      openssh.authorizedKeys.keys = sshKeys;
    };

    # Passwordless `sudo nixos-rebuild`. Keeps password prompts on every other
    # sudo invocation — only the rebuild path is whitelisted, so a compromised
    # shell still can't escalate to arbitrary root commands.
    security.sudo.extraRules = [
      {
        users = [ username ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # NixOS regenerates /etc/passwd from the declarative spec on every rebuild,
    # so a manual `chfn` would get clobbered (`description` is taken from the
    # JSON spec, and `mutableUsers = true` only protects the password field).
    # This per-user script runs after the `users` activation and writes the
    # GECOS field back from /etc/nixos/local/full-name-${username}, falling back
    # to the legacy single-user /etc/nixos/local/full-name. The files live
    # outside the Nix store so they survive rebuilds without entering git; seed
    # them via `nix run .#init-account` at install or edit directly and rebuild.
    system.activationScripts."applyLocalFullName-${username}" =
      lib.stringAfter [ "users" ] ''
        for nameFile in /etc/nixos/local/full-name-${username} /etc/nixos/local/full-name; do
          [ -r "$nameFile" ] || continue
          desired=$(${pkgs.coreutils}/bin/head -n 1 "$nameFile")
          [ -n "$desired" ] || continue
          current=$(${pkgs.getent}/bin/getent passwd ${username} \
            | ${pkgs.coreutils}/bin/cut -d: -f5)
          [ "$desired" = "$current" ] || ${pkgs.shadow}/bin/usermod -c "$desired" ${username}
          break
        done
      '';

    # home-manager identity. username/homeDirectory are set explicitly (rather
    # than relying on the home-manager NixOS module's auto-derivation from the
    # attr name) so it is correct in isolation. Shared home content (cursor,
    # stateVersion, …) and the role buckets attach automatically via
    # my.homeUsers — see modules/users/home-manager.nix + home-base.nix.
    home-manager.users.${username} = {
      home.username = username;
      home.homeDirectory = "/home/${username}";
    };
  };
}
