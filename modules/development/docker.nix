{
  flake.modules.nixos.development = {
    virtualisation.docker.enable = true;
    # The host's user gets the `docker` group from the mkUser builder
    # (lib/mk-user.nix's default extraGroups) so `docker` works without sudo.
    # Adding the group here would split the user's group membership across files.
  };
}
