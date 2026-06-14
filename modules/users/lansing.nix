# The `lansing` user. The account/home structure lives once in the shared
# builder (lib/mk-user.nix); only the values unique to lansing live here. A host
# gets lansing by importing nixos.user-lansing, which registers lansing into
# my.homeUsers (so the base + role home buckets attach automatically) and
# defaults my.primaryUser to "lansing".
import ../../lib/mk-user.nix {
  username = "lansing";
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFSIDoZWfx6cHP0Tp1xwi6cBnYopSd2YHbFugA7t32KN"
  ];
}
