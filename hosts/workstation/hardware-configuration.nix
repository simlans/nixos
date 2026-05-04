{ ... }:
{
  # Hand-written placeholder for the Framework 13 Pro (Intel Core Ultra 7
  # 358H, Panther Lake). The hardware did not exist at the time this
  # file was committed, so kernel module / firmware bits below are
  # the conservative Intel-laptop defaults. After the first boot, run
  #
  #   sudo nixos-generate-config --show-hardware-config
  #
  # and merge anything new it reports into this file. Do NOT add the
  # `fileSystems."/" = …;` or `boot.initrd.luks.devices.*` blocks
  # back — disko (disko/workstation.nix) is authoritative for those.
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
    "uas"
    "dm_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
