{ ... }:
{
  # Secret Service provider for libsecret consumers (1Password GUI's
  # libsecret bridge, browsers, …). The daemon is already pulled in
  # transitively via xdg-desktop-portal-gnome; making it explicit lets us
  # wire PAM so the login keyring stays in sync with the user account.
  services.gnome.gnome-keyring.enable = true;

  # `enableGnomeKeyring` adds pam_gnome_keyring.so to all three PAM phases:
  #   auth     → unlocks the keyring with the password just typed
  #   session  → starts the daemon if not running
  #   password → re-encrypts the keyring on `passwd` (uses the old+new pair)
  #
  # Without the `passwd` hook the keyring de-syncs on every password change.
  # Caveat: root-driven password changes (`sudo passwd <user>`, or
  # `nixos-enter -c 'passwd …'` during install) still bypass the sync,
  # because root never holds the old keyring password. That's fine at
  # install time — the keyring doesn't exist yet, so it gets created with
  # the right password on first login.
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  security.pam.services.passwd.enableGnomeKeyring = true;
}
