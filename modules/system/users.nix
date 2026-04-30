{ pkgs, ... }:
{
  users.mutableUsers = true;
  users.defaultUserShell = pkgs.zsh;

  users.users.lansing = {
    isNormalUser = true;
    description = "lansing";
    # No initialPassword: the bootstrap password is set via
    # `nixos-enter --root /mnt -c 'passwd lansing'` after disko-install
    # finishes and before the first reboot, so no plaintext or hash from
    # this repo ever lands in the world-readable Nix store.
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "audio"
      "docker"
    ];
  };
}
