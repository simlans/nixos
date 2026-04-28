{ pkgs, ... }:
{
  users.mutableUsers = true;
  users.defaultUserShell = pkgs.zsh;

  users.users.lansing = {
    isNormalUser = true;
    description = "lansing";
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
