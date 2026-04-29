# nixos-workstation

Declarative NixOS configuration for `battlestation` (AMD Ryzen 7 9800X3D, Radeon RX 9070 XT, NVMe + LUKS, Niri/Wayland).

## First-time install

### BIOS prerequisites

Before booting the installer:

1. Disable Secure Boot (it gets re-enabled at the end after key enrollment).
2. Put Secure Boot into **Setup Mode** — on ASRock B850: *Security → Secure Boot → Key Management → Reset to Setup Mode* (or *Clear Secure Boot Keys*). Without Setup Mode the auto-enrollment on first boot silently does nothing.
3. Confirm UEFI mode (no CSM / Legacy boot).

If Windows is already installed on the second NVMe with **BitLocker active**: have the recovery key ready (Microsoft account → Devices → BitLocker recovery keys). Clearing the firmware keys changes PCR 7, so the next Windows boot prompts for recovery once.

### Installation

On the target machine, booted from the **NixOS 25.11 minimal USB**. The second NVMe (Corsair MP600) is removed during installation, so the Samsung 970 EVO Plus is guaranteed to be `/dev/nvme0n1`.

```bash
# Keyboard layout (optional)
sudo loadkeys de

# Network: wired to the router → DHCP lease from 10.76.1.x comes up automatically
ping -c 1 nixos.org

# Confirm disk path
lsblk

# One-shot: partition + install from the remote flake.
# NIX_CONFIG enables flakes for both the outer `nix` call and the nested nix
# subprocesses spawned by disko-install. Editing /etc/nix/nix.conf does not work:
# on NixOS it is a read-only symlink into the immutable /nix/store. Passing only
# `--experimental-features` to nix would leave the children failing with
# "experimental Nix feature 'nix-command' is disabled".
sudo NIX_CONFIG="experimental-features = nix-command flakes" nix run \
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

### Finish Secure Boot setup

The first boot ran two systemd services from the Lanzaboote module:

- `generate-sb-keys.service` — created PK/KEK/db under `/etc/secureboot/keys`.
- `prepare-sb-auto-enroll.service` — exported signed `.auth` files to `/boot/loader/keys/auto/` (Microsoft keys included by default) and re-signed the ESP artifacts.

Verify before turning Secure Boot on:

```bash
sudo sbctl verify          # all entries under /boot must report "signed"
bootctl status             # expect: Secure Boot: disabled (setup)
```

Reboot. systemd-boot now sees the auto-enrollment payload in `/boot/loader/keys/auto/` and writes PK/KEK/db into the firmware autonomously (this only works because Setup Mode is active).

After the next boot, enter the BIOS once more and set **Secure Boot → Enabled**, save, exit.

```bash
bootctl status             # expect: Secure Boot: enabled (user)
sudo sbctl status          # Setup Mode: Disabled, Secure Boot: Enabled
```

Boot into Windows via the BIOS boot picker (F11) once. With BitLocker active, expect a one-time recovery prompt — type the recovery key, BitLocker re-binds to the new PCR 7 value, future boots are silent.

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
  system/boot.nix                        # Lanzaboote (Secure Boot), linuxPackages_latest, amd_pstate
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
sudo NIX_CONFIG="experimental-features = nix-command flakes" nix run \
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
