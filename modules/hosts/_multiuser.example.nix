# Example host proving multi-user support: home-manages BOTH lansing and bread
# on one machine (the "several users per host" goal). Not a real device — a
# minimal, non-secure-boot test target. Build and run it as a VM:
#   nixos-rebuild build-vm --flake .#multiuser && ./result/bin/run-multiuser-vm
# then log in as `lansing` and as `bread` (set their passwords first inside the
# VM, or rely on the greeter — both users exist with the same role buckets).
{ config, inputs, ... }:
{
  flake.nixosConfigurations.multiuser = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with config.flake.modules.nixos; [
      base
      desktop
      development
      user-lansing
      user-bread
      ({ lib, ... }: {
        networking.hostName = "multiuser";
        system.stateVersion = "25.11";

        # Each user aspect sets `my.primaryUser = mkDefault <name>`; with two
        # users those defaults collide on purpose, so a multi-user host must
        # pick the owner of the host's personal secrets (git identity, sunshine)
        # explicitly. That deliberate choice is the whole point of this host.
        my.primaryUser = "lansing";

        # Test target, not real hardware: drop the lanzaboote secure-boot from
        # `base` for plain systemd-boot and stub the disks so a bare
        # `nixos-rebuild build` evaluates. `build-vm` overrides both with the
        # qemu rootfs and a direct kernel boot, so they only matter for `build`.
        boot.lanzaboote.enable = lib.mkForce false;
        boot.loader.systemd-boot.enable = lib.mkForce true;
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        fileSystems."/boot" = {
          device = "/dev/disk/by-label/ESP";
          fsType = "vfat";
        };
      })
    ];
  };
}
