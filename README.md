# nixos-workstation

Declarative NixOS configuration for `battlestation` (AMD Ryzen 7 9800X3D, Radeon RX 9070 XT, NVMe + LUKS, Niri/Wayland).

## First-time install

### BIOS prerequisites

Before booting the installer:

1. Disable Secure Boot (it gets re-enabled at the end after key enrollment).
2. Put Secure Boot into **Setup Mode** — on ASRock B850: *Security → Secure Boot → Secure Boot Mode → Custom* and then *Clear Secure Boot Keys*. Without Setup Mode the auto-enrollment on first boot silently does nothing.
3. Confirm UEFI mode (no CSM / Legacy boot).

If Windows is already installed on the second NVMe with **BitLocker active**: have the recovery key ready — sign in at <https://account.microsoft.com/devices/recoverykey> (or <https://aka.ms/myrecoverykey>) with the Microsoft account tied to the Windows install. Clearing the firmware keys changes PCR 7, so the next Windows boot prompts for recovery once.

### Installation

On the target machine, booted from the **NixOS 25.11 minimal USB**. The second NVMe (Corsair MP600) is removed during installation, so the Samsung 970 EVO Plus is guaranteed to be `/dev/nvme0n1`.

```bash
# Keyboard layout (optional)
sudo loadkeys de

# Network: wired to the router → DHCP lease from your LAN comes up automatically
ping -c 1 nixos.org

# Confirm disk path
lsblk

# One-shot: partition + install from the remote flake.
#
# NIX_CONFIG enables flakes for both the outer `nix` call and the nested nix
# subprocesses spawned by disko-install. Editing /etc/nix/nix.conf does not
# work: on NixOS it is a read-only symlink into the immutable /nix/store.
# Passing only `--experimental-features` would leave the children failing
# with "experimental Nix feature 'nix-command' is disabled".
#
# `tarball-ttl = 0` plus `--refresh` force a fresh fetch of the flake
# metadata. Without this, a previous install attempt that resolved this URL
# can pin nix to a stale commit (e.g. one with a missing flake.lock entry),
# and you get "cannot write modified lock file" until the cache expires.
sudo NIX_CONFIG="experimental-features = nix-command flakes
tarball-ttl = 0" nix --refresh run \
  github:nix-community/disko/latest#disko-install -- \
  --flake github:simlans/nixos-workstation#battlestation \
  --disk main /dev/nvme0n1 \
  --write-efi-boot-entries
# → prompts only for the LUKS passphrase. disko-install runs
#   `nixos-install --no-root-passwd`, so no interactive root prompt
#   appears. The flake intentionally has no initialPassword/hashedPassword,
#   so the user account is created locked — set a password before the first
#   reboot via nixos-enter (the new system stays mounted at /mnt after
#   disko-install exits):
sudo nixos-enter --root /mnt -c 'passwd lansing'
```

`reboot`, pull the USB, type the LUKS passphrase → `tuigreet` comes up. Log
in as `lansing` with the password just set. Root stays without a password
(`PermitRootLogin = "no"`, sudo via `wheel`).

Set the **real** password at this `nixos-enter` step — not a placeholder you
plan to rotate later. The login GNOME keyring (Secret Service backend used by
1Password's libsecret bridge etc.) gets created on first login encrypted
with whatever password is active then. PAM keeps it in sync on later
interactive `passwd` runs (`modules/desktop/keyring.nix`), but root-driven
changes (`sudo passwd`, `nixos-enter -c 'passwd …'`) cannot — root never sees
the old keyring password. If you're stuck with a mismatched keyring, fix it
once with `seahorse` (change keyring password) or remove
`~/.local/share/keyrings/{login.keyring,user.keystore}` and let it regenerate.

### Finish Secure Boot setup

The first boot ran two systemd services from the Lanzaboote module:

- `generate-sb-keys.service` — created PK/KEK/db under `/etc/secureboot/keys`.
- `prepare-sb-auto-enroll.service` — exported signed `.auth` files to `/boot/loader/keys/auto/` (Microsoft keys included by default) and re-signed the ESP artifacts.

Verify before turning Secure Boot on:

```bash
sudo sbctl verify          # see note below
sudo bootctl status        # expect: Secure Boot: disabled (setup)
```

`sbctl verify` will report `/boot/EFI/nixos/kernel-*.efi` (and potentially the initrd) as **not signed** — leave them that way. Lanzaboote verifies those files via a content hash inside the signed UKI stub, not via a PE signature; signing them changes the bytes, breaks the hash check, and the stub aborts the next boot with "Kernel hash does not match". The signed entries that *must* report "signed" are `BOOTX64.EFI`, `systemd-bootx64.efi`, and `/boot/EFI/Linux/nixos-generation-*.efi`.

Reboot. systemd-boot now sees the auto-enrollment payload in `/boot/loader/keys/auto/` and writes PK/KEK/db into the firmware autonomously (this only works because Setup Mode is active).

After the next boot, enter the BIOS once more and set **Secure Boot → Enabled**, save, exit.

```bash
bootctl status             # expect: Secure Boot: enabled (user)
sudo sbctl status          # Setup Mode: Disabled, Secure Boot: Enabled
```

Boot into Windows via the BIOS boot picker (F11) once. With BitLocker active, expect a one-time recovery prompt — fetch the key from <https://account.microsoft.com/devices/recoverykey>, type it in, BitLocker re-binds to the new PCR 7 value, future boots are silent.

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
  system/
    base.nix                             # locale, time, nix settings, OS toolbox
    boot.nix                             # Lanzaboote (Secure Boot), linuxPackages_latest, amd_pstate
    network.nix                          # NetworkManager, bluetooth, firewall
    users.nix                            # user lansing (incl. docker group)
    openssh.nix                          # SSH server + authorized keys
    tailscale.nix                        # tailscaled (auth key bootstrapped post-install)
  desktop/
    niri.nix                             # Niri WM, greetd+tuigreet, xdg-portal
    fonts.nix                            # Noto / Fira / JetBrains Nerd Fonts
    audio.nix                            # PipeWire + rtkit
    tools.nix                            # alacritty, fuzzel, waybar, swaylock, mako, ...
  apps/                                  # firefox, onepassword (GUI+CLI), discord
  gaming/                                # steam (+ 32-bit graphics)
  development/                           # claude-code, docker
home/lansing/
  default.nix                            # Home Manager root: identity + imports
  cli.nix                                # ripgrep, fd, bat, eza, fzf, jq, yq, tree, htop, file
  onepassword.nix                        # op-cache + IdentityAgent → 1P GUI agent
  shell/
    zsh.nix                              # zsh + oh-my-zsh + Powerlevel10k, aliases, history, 1P signin, auto-tmux
    p10k/p10k.zsh                        # Powerlevel10k config (lean, kubecontext-aware right prompt)
    tmux/                                # tmux + pinned gpakosz/.tmux + tmux.conf.local
    direnv.nix                           # direnv + nix-direnv
  development/
    git.nix                              # git + gh + delta (SSH signing on by default)
    neovim.nix                           # neovim + dracula + nerdtree/coc/startify/snippets
    kubernetes/                          # kubectl, k9s, fluxcd + k9s skin
    golang.nix                           # go + gotools
```

## First-time setup after the install

Once the system boots into Niri, finish the per-user bootstrap:

1. **1Password GUI** — open the app, sign in to the personal account, then go to
   *Settings → Developer* and enable **Use the SSH agent** (writes
   `~/.1password/agent.sock`, which `home/lansing/onepassword.nix` already wires
   into `~/.ssh/config` and the SSH-based git signing path). Git is configured
   to commit-sign by default in `home/lansing/git.nix` — once the GUI agent is
   running, signed commits just work.

2. **1Password CLI** — sign in once so `op` lookups don't prompt:
   ```bash
   eval $(op signin --account my.1password.eu)
   op whoami
   ```
   The zsh init in `home/lansing/zsh.nix` picks up the session for new shells
   automatically and re-exports it into tmux.

3. **Tailscale** — the daemon is on but the node isn't joined. Run the flake app
   once; it prompts for the auth key and runs `tailscale up`:
   ```bash
   nix run .#tailscale-up                                                    # interactive prompt
   op read 'op://nixos/tailscale-nixos-authkey/credential' | nix run .#tailscale-up  # piped
   ```
   Tailscale persists the node identity under `/var/lib/tailscale`, so this is a
   one-shot per machine.

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
