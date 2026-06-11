{ ... }:
{
  virtualisation.docker.enable = true;
  # `lansing` is added to the `docker` group in modules/system/users.nix so
  # that `docker` works without sudo. Adding the group here would split the
  # user's group membership across files.
}
