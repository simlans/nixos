# System-wide user-account policy. The actual accounts live in their own
# aspects (modules/users/<name>.nix → nixos.user-<name>); a host gets a user
# by importing that bucket.
{
  flake.modules.nixos.base = { pkgs, ... }: {
    # Passwords are set imperatively at install time (`nixos-enter … passwd`),
    # never from this public repo — so accounts must stay mutable.
    users.mutableUsers = true;
    users.defaultUserShell = pkgs.zsh;
  };
}
