{
  # Same disk layout as battlestation: GPT, 1 GiB FAT32 ESP, LUKS
  # container holding ext4 root with TRIM enabled. Lives in its own
  # file (rather than reusing disko/battlestation.nix) so the flake
  # exposes one disko module per host and `disko-install --flake
  # .#workstation` resolves a unique import path.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        luks = {
          size = "100%";
          label = "luks";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
