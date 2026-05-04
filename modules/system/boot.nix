{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
    autoGenerateKeys.enable = true;
    autoEnrollKeys.enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.systemPackages = [ pkgs.sbctl ];

  # NOTE: Do not sign /boot/EFI/nixos/kernel-*.efi (or initrd) with sbctl.
  # Lanzaboote verifies those files at boot via a content **hash** stored
  # inside the signed UKI stub, not via PE signatures. Appending a sbctl
  # signature mutates the file bytes, the hash check fails, and the stub
  # aborts with "Kernel hash does not match". The bare files appear as
  # "is not signed" in `sbctl verify` and that is the required state.
}
