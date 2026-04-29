{ pkgs, ... }:
{
  users.mutableUsers = true;
  users.defaultUserShell = pkgs.zsh;

  users.users.lansing = {
    isNormalUser = true;
    description = "lansing";
    # disko-install runs nixos-install with --no-root-passwd, so the install
    # never prompts for a password. Without an initialPassword neither root
    # nor lansing get a hash in /etc/shadow, both accounts are locked, and
    # the first login is impossible. Plaintext is acceptable here because
    # this is a one-shot bootstrap value — change it with `passwd` on first
    # login.
    initialPassword = "changeme";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "audio"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFSIDoZWfx6cHP0Tp1xwi6cBnYopSd2YHbFugA7t32KN"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
