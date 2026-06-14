# Example second user, structurally identical to lansing via the shared builder
# (lib/mk-user.nix) — proof that the host modules are decoupled from any
# specific username. A host gets bread by importing nixos.user-bread.
import ../../lib/mk-user.nix {
  username = "bread";
  # TODO: add bread's real public SSH key(s). Empty = password-only login, set
  # at install via `nixos-enter --root /mnt -c 'passwd bread'`.
  sshKeys = [ ];
}
