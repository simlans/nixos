# nixos-workstation

Declarative NixOS configuration for `battlestation` (AMD Ryzen 7 9800X3D, Radeon RX 9070 XT, NVMe + LUKS, Niri/Wayland).

## First-time install

On the target machine, booted from the **NixOS 25.11 minimal USB**. The second NVMe (Corsair MP600) is removed during installation, so the Samsung 970 EVO Plus is guaranteed to be `/dev/nvme0n1`.

```bash
# Keyboard layout (optional)
loadkeys de

# Network: wired to the router → DHCP lease from 10.76.1.x comes up automatically
ping -c 1 nixos.org

# Confirm disk path
lsblk

# One-shot: partition + install from the remote flake
sudo nix --experimental-features 'nix-command flakes' run \
  github:nix-community/disko/latest#disko-install -- \
  --flake github:simlans/nixos-workstation#battlestation \
  --disk main /dev/nvme0n1 \
  --write-efi-boot-entries
# → prompts for: LUKS passphrase, root password
```

`reboot`, pull the USB, type the LUKS passphrase → `tuigreet` comes up.

### First login: set the user password

`tuigreet` only lists users that have a password set. On first boot switch to a TTY with Ctrl+Alt+F2 and log in as `root`:

```bash
passwd lansing
```

Switch back with Ctrl+Alt+F1 to `tuigreet` and log in as `lansing`.

## Subsequent rebuilds

```bash
git clone https://github.com/simlans/nixos-workstation ~/nixos-workstation
sudo nixos-rebuild switch --flake ~/nixos-workstation#battlestation
```

## Layout

```
flake.nix                                # inputs + nixosConfigurations.battlestation
disko/battlestation.nix                  # GPT: 1 GiB ESP (FAT32) + LUKS→ext4 root
hosts/battlestation/
  default.nix                            # host imports + hostName + stateVersion
  hardware-configuration.nix             # AMD CPU, NVMe, AMD GPU (hand-tuned)
modules/
  system/base.nix                        # locale, time, nix settings, packages
  system/boot.nix                        # systemd-boot, linuxPackages_latest, amd_pstate
  system/network.nix                     # NetworkManager, bluetooth, firewall
  system/users.nix                       # user lansing, openssh
  desktop/niri.nix                       # Niri, greetd+tuigreet, PipeWire, fonts
  desktop/apps.nix                       # Firefox, 1Password (GUI+CLI), Steam, Discord
home/lansing/default.nix                 # Home Manager: zsh, git, CLI tools
```

## Hardware

- CPU: AMD Ryzen 7 9800X3D (Zen 5 X3D, AM5)
- GPU: AMD Radeon RX 9070 XT (RDNA 4 / Navi 48) — needs kernel ≥ 6.14, hence `linuxPackages_latest`
- Mainboard: ASRock B850 Riptide WiFi (Realtek 2.5G LAN, MediaTek RZ717 = MT7925 WiFi 7 + Bluetooth)
- RAM: 64 GB DDR5-6000 (XMP/EXPO in BIOS)
- OS disk: Samsung 970 EVO Plus 500 GB (PCIe 3.0 NVMe)
- 2nd disk (Corsair MP600): later for Windows; boot selection via BIOS (F11 at POST), no NixOS config needed

## Fallback: manual install

If something needs editing before install (e.g. `disko/battlestation.nix`):

```bash
nix-shell -p git
git clone https://github.com/simlans/nixos-workstation /tmp/cfg
cd /tmp/cfg
# … edit …
sudo nix --experimental-features 'nix-command flakes' run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount ./disko/battlestation.nix
sudo nixos-install --flake .#battlestation
```

## Validation (locally on a system with `nix`)

```bash
nix flake check --no-build
nix flake show
nix eval .#nixosConfigurations.battlestation.config.system.build.toplevel.drvPath
```
