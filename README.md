# nixos-workstation

Declarative NixOS configuration for two of simlans's machines:

- **`battlestation`** — AMD Ryzen 7 9800X3D desktop, Radeon RX 9070 XT, NVMe + LUKS, Niri/Wayland.
- **`workstation`** — Framework 13 Pro laptop (Intel Core Ultra 7 358H / Panther Lake), Intel Arc iGPU, NVMe + LUKS, Niri/Wayland, plus Slack.

Two hosts, one flake, shared modules. Throughout this README, replace `<host>` with either `battlestation` or `workstation` depending on which machine you're working on.

## First-time install

### BIOS prerequisites

Before booting the installer:

1. Disable Secure Boot (it gets re-enabled at the end after key enrollment).
2. Put Secure Boot into **Setup Mode**:
   - **battlestation (ASRock B850)**: *Security → Secure Boot → Secure Boot Mode → Custom* and then *Clear Secure Boot Keys*.
   - **workstation (Framework 13 Pro, InsydeH2O)**: *Administer Secure Boot → Erase all Secure Boot Settings* — this also drops the firmware into Setup Mode.
   Without Setup Mode the auto-enrollment on first boot silently does nothing.
3. Confirm UEFI mode (no CSM / Legacy boot).

If Windows is already installed on the second NVMe with **BitLocker active** (battlestation only): have the recovery key ready — sign in at <https://account.microsoft.com/devices/recoverykey> (or <https://aka.ms/myrecoverykey>) with the Microsoft account tied to the Windows install. Clearing the firmware keys changes PCR 7, so the next Windows boot prompts for recovery once.

### Installation

On the target machine, booted from the **NixOS 25.11 minimal USB**.

- **battlestation**: the second NVMe (Corsair MP600) is removed during installation, so the Samsung 970 EVO Plus is guaranteed to be `/dev/nvme0n1`.
- **workstation**: the Framework 13 Pro has exactly one M.2 slot, so the Phison NVMe is always `/dev/nvme0n1`.

```bash
# Keyboard layout (optional)
sudo loadkeys de   # battlestation has an ISO/DE keyboard
sudo loadkeys us   # workstation has an ANSI/US keyboard

# Network: wired to the router → DHCP lease from your LAN comes up automatically
ping -c 1 nixos.org

# Confirm disk path
lsblk

# Workstation only: note the WisdPi 10G expansion-card USB ID before
# wiping the disk, so any out-of-tree driver can be wired up later.
lsusb

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
  --flake github:simlans/nixos-workstation#<host> \
  --disk main /dev/nvme0n1 \
  --write-efi-boot-entries
# → prompts only for the LUKS passphrase. disko-install runs
#   `nixos-install --no-root-passwd`, so no interactive root prompt
#   appears. The flake intentionally has no initialPassword/hashedPassword,
#   so the user account is created locked.
#
# Bootstrap the `lansing` account in one step: prompts for the login
# password (via `nixos-enter -c 'passwd lansing'`) and the real name,
# then writes the GECOS source to /mnt/etc/nixos/local/full-name. The
# activation script `applyLocalFullName` in `modules/system/users.nix`
# re-applies the realname via usermod on every rebuild — the file lives
# outside the Nix store so it survives rebuilds without ever entering
# git. The new system stays mounted at /mnt after disko-install exits,
# which is why this runs before reboot.
NIX_CONFIG="experimental-features = nix-command flakes" \
  nix run github:simlans/nixos-workstation#init-account
```

`reboot`, pull the USB, type the LUKS passphrase → `ReGreet` (the GTK
greeter we run on top of greetd) comes up. Log in as `lansing` with the
password just set. Root stays without a password (`PermitRootLogin = "no"`,
sudo via `wheel`).

Set the **real** password at this `nixos-enter` step — not a placeholder you
plan to rotate later. The login GNOME keyring (Secret Service backend used by
1Password's libsecret bridge etc.) gets created on first login encrypted
with whatever password is active then. PAM keeps it in sync on later
interactive `passwd` runs (`modules/desktop/keyring.nix`), but root-driven
changes (`sudo passwd`, `nixos-enter -c 'passwd …'`) cannot — root never sees
the old keyring password. If you're stuck with a mismatched keyring, fix it
once with `seahorse` (change keyring password) or remove
`~/.local/share/keyrings/{login.keyring,user.keystore}` and let it regenerate.

First-boot caveat for the GECOS step: the lock-screen greeting will read
`Welcome back, lansing!` until the first `sudo nixos-rebuild switch` runs
the activation script — see [Subsequent rebuilds](#subsequent-rebuilds)
just below; that step is part of the normal install flow anyway.

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
sudo nixos-rebuild switch --flake ~/nixos-workstation#<host>
```

After cloning, run `direnv allow` in the repo root once. That triggers the
flake devShell's `shellHook` (provided by `git-hooks.nix`), which installs a
`gitleaks` pre-commit hook into `.git/hooks/`. The hook blocks any commit
that stages a private key or other high-entropy secret pattern. To run the
scan manually:

```bash
nix flake check
```

### Change the GECOS / lock-screen real name

`/etc/nixos/local/full-name` is the single source of truth for the
description column of `/etc/passwd`. Edit the file, then rebuild — the
activation script in `modules/system/users.nix` picks up the new value
via `usermod` on the next switch:

```bash
sudoedit /etc/nixos/local/full-name
sudo nixos-rebuild switch --flake ~/nixos-workstation#<host>
```

### Editing secrets

`secrets/personal.yaml` is age-encrypted. The repo's `.envrc` pulls the
user age private key from 1Password (`op://Private/nixos-sops-keyfile`,
a Document item) and exports it as `SOPS_AGE_KEY`, so `sops` works as
long as you're inside the direnv'd repo shell and the 1P CLI is
unlocked. No on-disk `~/.config/sops/age/keys.txt` required:

```bash
sops secrets/personal.yaml             # opens $EDITOR with plaintext, re-encrypts on save
```

Commit the resulting file. The encrypted form is what gets pushed.

To add a new secret, declare it in `modules/system/sops.nix`
(`sops.secrets."<key>" = { owner = "lansing"; };`), then reference its
decrypted path from a NixOS module via `config.sops.secrets."<key>".path`
or from a home-manager module via `osConfig.sops.secrets."<key>".path`.

## Layout

```
flake.nix                                # inputs + nixosConfigurations.{battlestation,workstation} + apps.{tailscale-up,init-account,sops-onboard-host}
.sops.yaml                               # sops recipients (per-host SSH host pubkeys + per-user age pubkey)
secrets/personal.yaml                    # sops-encrypted YAML — git/{author_name,author_email,github_user}
disko/battlestation.nix                  # GPT: 1 GiB ESP (FAT32) + LUKS→ext4 root (desktop NVMe)
disko/workstation.nix                    # same layout, separate file so #workstation has its own module path
hosts/battlestation/
  default.nix                            # host imports + hostName + stateVersion + ISO keyboard + DP-1 niri output
  hardware-configuration.nix             # AMD CPU (kvm-amd, amd_pstate=active, microcode), NVMe initrd modules
hosts/workstation/
  default.nix                            # host imports + hostName + stateVersion + ANSI keyboard + eDP-1 niri output
  hardware-configuration.nix             # Intel CPU (kvm-intel, microcode), NVMe + thunderbolt initrd modules — placeholder, regenerate after first boot
modules/
  system/
    base.nix                             # locale, time, nix settings, OS toolbox
    boot.nix                             # Lanzaboote (Secure Boot), linuxPackages_latest
    network.nix                          # NetworkManager, bluetooth, firewall
    users.nix                            # user lansing (incl. docker group)
    openssh.nix                          # SSH server + authorized keys
    sops.nix                             # sops-nix wrapper: defaultSopsFile + git/* secrets owned by lansing
    tailscale.nix                        # tailscaled (auth key bootstrapped post-install)
  desktop/
    niri.nix                             # Niri WM, greetd+ReGreet, xdg-portal
    keyboard-layout.nix                  # `lansing.desktop.{keyboardLayout,niriOutputs}` options + TTY keymap
    laptop.nix                           # workstation-only: nixos-hardware framework module, fprintd, fwupd, thermald, lid behaviour
    fonts.nix                            # Noto / Fira / JetBrains Nerd Fonts
    audio.nix                            # PipeWire + rtkit
    tools.nix                            # mako, wl-clipboard, grim, slurp, ...
  apps/                                  # firefox (+ 1P extension), onepassword (GUI+CLI), discord, signal, spotify, opencloud, slack (workstation only)
  gaming/                                # steam (+ 32-bit graphics), lutris (+ umu-launcher → GE-Proton for non-Steam Windows games)
  development/                           # claude-code (unstable), docker
home/lansing/
  default.nix                            # Home Manager root: identity + imports
  cli.nix                                # ripgrep, fd, bat, eza, jq, yq, tree, htop, file
  onepassword.nix                        # op-cache + IdentityAgent → 1P GUI agent
  shell/
    zsh.nix                              # zsh + oh-my-zsh + Powerlevel10k, aliases, history, auto-tmux
    p10k/p10k.zsh                        # Powerlevel10k config (lean, kubecontext-aware right prompt)
    tmux/                                # tmux + pinned gpakosz/.tmux + tmux.conf.local
    direnv.nix                           # direnv + nix-direnv
    fzf.nix                              # fzf + zsh integration (Ctrl+R history, Ctrl+T files, Alt+C cd)
  development/
    git.nix                              # git + gh + delta (SSH signing on by default)
    neovim/                              # neovim + LazyVim (lazy.nvim dev path → Nix-pinned plugins, treesitter parsers prebuilt, no mason)
    kubernetes/                          # kubectl, k9s, fluxcd + k9s skin
    golang.nix                           # go + gotools
```

## First-time setup after the install

Once the system boots into Niri, finish the per-user bootstrap:

1. **1Password GUI** — open the app, sign in to the personal account, then in
   *Settings → Developer* enable **Use the SSH agent**. That writes
   `~/.1password/agent.sock`, which `home/lansing/onepassword.nix` wires into
   `~/.ssh/config` and the SSH-based git signing path. Git is configured to
   commit-sign by default in `home/lansing/development/git.nix` — once the GUI
   agent is running, signed commits just work. Cross-repo `.envrc` files
   (e.g. `~/Projects/homelab`) that still call `op-cache read 'op://...'`
   additionally need *Integrate with 1Password CLI* enabled in the same dialog.

   The Niri session itself no longer depends on 1Password — the lock-screen
   real name is sourced from `/etc/passwd` (seeded at install time via
   `nix run .#init-account`), so noctalia-shell starts cleanly even if the
   1P GUI hasn't been launched yet. The bullets above are still required for
   signed commits, but only once you start pushing code, not for the desktop
   to come up.

2. **sops-nix bootstrap** — this repo's commit identity (private name + email
   + `GITHUB_USER`) lives in `secrets/personal.yaml`, age-encrypted. The first
   `nixos-rebuild switch` on a fresh host succeeds even before sops is set up
   — `sops-install-secrets.service` simply fails to decrypt because the host's
   pubkey isn't yet in `.sops.yaml`, and `~/.envrc`'s `[ -r ... ]` guard skips
   the export. New shells start cleanly, just without the env-vars.

   From any host where the repo's `.envrc` has loaded `SOPS_AGE_KEY`
   (i.e. you're inside the direnv'd repo shell and the 1P CLI is
   unlocked), one command does the whole onboarding:

   ```bash
   nix run .#sops-onboard-host -- lansing@<ssh-target> <flake-host>
   #   <ssh-target>  anything `ssh` accepts — IP, hostname, Tailscale
   #                 MagicDNS name, ~/.ssh/config alias.
   #   <flake-host>  logical name; must match a nixosConfigurations.<name>
   #                 entry in flake.nix (battlestation or workstation).
   #
   # Common case (DNS resolves the host's name): both identical, e.g.
   nix run .#sops-onboard-host -- lansing@workstation workstation
   ```

   The script SSHs to the target, derives its age recipient from
   `/etc/ssh/ssh_host_ed25519_key.pub`, inserts it into `.sops.yaml`, and
   runs `sops updatekeys secrets/personal.yaml`. SSH works because
   `modules/system/openssh.nix` bakes lansing's pubkey into every machine
   and the 1P SSH agent serves the matching private key. The script is
   idempotent — re-running with an already-onboarded `<flake-host>` is a
   no-op.

   Then commit + push + rebuild on the new host as the script's "Done. Now…"
   output spells out:

   ```bash
   git -C ~/Projects/nixos-workstation commit -am "sops: onboard <flake-host>"
   git -C ~/Projects/nixos-workstation push
   ssh lansing@<ssh-target>
     git -C ~/Projects/nixos-workstation pull
     sudo nixos-rebuild switch --flake ~/Projects/nixos-workstation#<flake-host>
   ```

   After the rebuild, `/run/secrets/git/{author_name,author_email,github_user}`
   exist (mode 0400, owner `lansing`) and new shells pick up
   `GIT_AUTHOR_*`/`GITHUB_USER` from them.

   If the new host has no network yet (so the SSH leg of `sops-onboard-host`
   fails), run the conversion locally at its console and paste the
   `age1...` line into `.sops.yaml` by hand, then `sops updatekeys` from
   battlestation:
   ```bash
   nix shell nixpkgs#ssh-to-age -c sh -c 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'
   ```

3. **Tailscale** — the daemon is on but the node isn't joined. Run the flake app
   once:
   ```bash
   nix run .#tailscale-up                            # default: prints a browser login URL
   echo "$tskey" | nix run .#tailscale-up            # headless: pipe a one-shot auth key
   ```
   The auth key is intentionally not stored anywhere — generate one ad-hoc at
   <https://login.tailscale.com/admin/settings/keys> when you actually need
   the headless variant. Tailscale persists the node identity under
   `/var/lib/tailscale`, so this is a one-shot per machine.

4. **Sunshine + Moonlight (battlestation only)** — the streaming host
   (`services.sunshine`, configured in `modules/gaming/sunshine.nix`) is
   already enabled, firewall ports are open, KMS capture and VA-API
   encoding are wired up, and the user systemd unit auto-starts on
   graphical login. Two one-time interactive steps remain:

   1. **Seed the WebUI admin credentials via sops** — pick a strong
      password, then:
      ```bash
      sops secrets/personal.yaml
      ```
      Add a `sunshine:` block alongside the existing `git:` block:
      ```yaml
      sunshine:
        admin_user: lansing
        admin_pass: <strong password>
      ```
      Commit + push, then on battlestation:
      ```bash
      sudo nixos-rebuild switch --flake ~/Projects/nixos-workstation#battlestation
      ```
      The user unit's `ExecStartPre` calls `sunshine --creds` on every
      start to keep `~/.config/sunshine/sunshine_state.json` in sync with
      the sops values — change the password later by editing the secret
      and rebuilding.

   2. **Pair each Moonlight client by PIN** — install a Moonlight client
      on the target device (downloads at <https://moonlight-stream.org/>;
      `moonlight-qt` for Linux/macOS/Windows, native apps for iOS/Android,
      `moonlight-embedded` for older Smart-TV boxes). The battlestation
      announces itself over mDNS / avahi, so the client lists it
      automatically when on the same LAN; over Tailscale it's reachable
      by MagicDNS without any additional firewall config (Sunshine binds
      to all interfaces). Tap the host, the client displays a PIN, then
      open `https://battlestation:47990/` (accept the self-signed cert),
      log in with the sops creds, navigate to *PIN*, and enter the PIN.
      Once per device, ever — Sunshine remembers the cert fingerprint.

   Pre-configured Moonlight apps: **Desktop** (raw niri session for
   remote control) and **Steam Big Picture** (auto-launches Steam in
   couch-friendly mode). Add more entries by appending to
   `services.sunshine.applications.apps` in `modules/gaming/sunshine.nix`.

   Recovery: if the admin login ever gets wedged (e.g. the state file
   gets corrupted), delete `~/.config/sunshine/sunshine_state.json` on
   battlestation and run `systemctl --user restart sunshine`; the
   ExecStartPre re-seeds from sops on the next start.

## External displays (workstation)

Niri does per-output workspaces by default — each screen has an independent vertical workspace stack, and `Mod+Up`/`Mod+Down` only scrolls the workspaces of the currently focused output. No `workspaces { … }` block is needed to keep the laptop and an external monitor independent.

The `eDP-1` block already in `lansing.desktop.niriOutputs` (`hosts/workstation/default.nix`) is enough on its own. If no external monitor is plugged in, niri runs on the internal panel only; any monitor that gets plugged in afterwards is auto-detected with niri's defaults (preferred mode from EDID, scale 1, position to the right of existing outputs). Add an explicit `output { … }` block per external monitor when you want deterministic position, mode, or scale.

### Identify outputs by EDID, not by connector name

Niri accepts either form as the output identifier:

- **Connector name** (`eDP-1`, `DP-1`, `DP-2`, …) — depends on which USB-C port the cable is in and on the order the kernel enumerates outputs at boot. Brittle across docks, adapters, and reboots.
- **EDID `"Make Model Serial"`** — read directly from the monitor; stable across ports, adapters, and docks.

For external monitors prefer EDID. With the monitor connected, run `niri msg outputs` and concatenate the `Make`, `Model`, and `Serial` fields with single spaces. Some monitors don't ship a serial in EDID — niri reports `Unknown` in that field, and the resulting identifier (e.g. `"BNQ BenQ_PD3420Q Unknown"`) is still a valid match.

### Position math is in logical (post-scale) pixels

The internal panel runs at 2880×1920 with `scale 1.5`, so its logical size is **1920×1280**. A 3440×1440 monitor at `scale 1.0` placed directly to the right of the laptop screen needs `position x=1920 y=0`. To bottom-align the external monitor with the laptop screen (laptop open on the desk next to it) use `position x=1920 y=-160` (`-160 = 1280 − 1440`).

### Example: home-office monitor + office monitor

```nix
# In hosts/workstation/default.nix
lansing.desktop.niriOutputs = ''
  output "eDP-1" {
      mode "2880x1920@120.000"
      scale 1.5
      position x=0 y=0
  }

  // Home office: 3440×1440 ultrawide via USB-C → HDMI adapter
  output "TODO Make Model Serial (home)" {
      mode "3440x1440"
      scale 1
      position x=1920 y=0
  }

  // Office: 3440×1440 ultrawide via direct USB-C
  output "TODO Make Model Serial (office)" {
      mode "3440x1440"
      scale 1
      position x=1920 y=0
  }
'';
```

Replace the `TODO …` strings with the values reported by `niri msg outputs` once each monitor is connected for the first time, then `sudo nixos-rebuild switch --flake .#workstation`. Output blocks for monitors that aren't currently connected are kept on file by niri and applied as soon as the matching EDID shows up, so committing all known monitors at once is fine.

Hot-plug works automatically: niri creates the output on connect (applying any matching `output` block), folds the workspaces back into `eDP-1` on disconnect, and brings them back on reconnect. No daemon restart, no logout.

### Pinning an app to a specific output

If a window should always open on a particular monitor, add a `window-rule` to `home/lansing/desktop/niri.kdl` (outside the `@OUTPUTS@` placeholder area, since the rule is host-agnostic):

```
window-rule {
    match app-id="Slack"
    open-on-output "TODO Make Model Serial (office)"
}
```

When the named output isn't connected, niri falls back to the currently focused output. Once the EDID strings have been filled in, mirror them into `AGENTS.md`'s workstation hardware table so they don't live only in tribal knowledge.

## Hardware

### battlestation

- CPU: AMD Ryzen 7 9800X3D (Zen 5 X3D, AM5)
- GPU: AMD Radeon RX 9070 XT (RDNA 4 / Navi 48) — needs kernel ≥ 6.14, hence `linuxPackages_latest`
- Mainboard: ASRock B850 Riptide WiFi (Realtek 2.5G LAN, MediaTek RZ717 = MT7925 WiFi 7 + Bluetooth)
- RAM: 64 GB DDR5-6000 (XMP/EXPO in BIOS)
- OS disk: Samsung 970 EVO Plus 500 GB (PCIe 3.0 NVMe)
- 2nd disk (Corsair MP600): later for Windows; boot selection via BIOS (F11 at POST), no NixOS config needed

### workstation

- CPU: Intel Core Ultra 7 358H (Panther Lake / Series 3, 4P + 8E + 4LP cores up to 4.8 GHz)
- GPU: Intel Arc Graphics (integrated)
- Chassis: Framework 13 Pro (Series 3), bezel + keyboard ANSI/US, Graphite
- RAM: 64 GB LPCAMM2 LPDDR5X
- OS disk: Phison PS5031-E31T 2 TB PCIe 5.0 NVMe (M.2 2280, only slot on the FW13 Pro)
- Display: 2.8K touchscreen (2880×1920 @ 120 Hz typically) — runs at niri `scale 1.5`
- Battery: 74 Wh
- Power adapter: 100 W USB-C (EU/KR plug)
- Expansion cards: 3× USB-C, 1× USB-A (gen 2), 1× HDMI (3rd gen), 1× WisdPi 10G Ethernet, 1× SD
- Fingerprint: Goodix sensor (handled by `services.fprintd` from `modules/desktop/laptop.nix`)

### Framework 13 Pro quirks

- **Secure Boot reset path** (InsydeH2O, not AMI): *Administer Secure Boot → Erase all Secure Boot Settings* drops the firmware into Setup Mode so Lanzaboote's auto-enrollment can install PK/KEK/db on the next boot.
- **First `fwupd update`**: Framework distributes BIOS + EC firmware via LVFS. Some EC blobs aren't db-signed; if `fwupdmgr update` fails, toggle Secure Boot **off** in the BIOS, run the update, and re-enable Secure Boot afterwards.
- **Fingerprint enrollment** (one-time, after first boot): `sudo fprintd-enroll lansing`. The PAM hooks for `login` and `sudo` are already wired up in `modules/desktop/laptop.nix`.
- **Touchscreen**: handled by libinput + niri out of the box, no extra config needed.
- **2.8K display**: niri runs the panel at `scale 1.5`. Verify the exact mode string with `niri msg outputs` after the first boot and adjust `lansing.desktop.niriOutputs` in `hosts/workstation/default.nix` if necessary.
- **WisdPi 10G**: USB-C 10GbE expansion card, Linux driver depends on the chipset (Aquantia `atlantic` or Realtek `r8152` — both mainline). Run `lsusb` from the install USB and add the chipset note to `AGENTS.md` once known.

## Fallback: manual install

If something needs editing before install (e.g. `disko/<host>.nix`):

```bash
nix-shell -p git
git clone https://github.com/simlans/nixos-workstation /tmp/cfg
cd /tmp/cfg
# … edit …
sudo NIX_CONFIG="experimental-features = nix-command flakes" nix run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount ./disko/<host>.nix
sudo nixos-install --flake .#<host>
```

## Validation (locally on a system with `nix`)

```bash
nix flake check --no-build
nix flake show
nix eval .#nixosConfigurations.battlestation.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.workstation.config.system.build.toplevel.drvPath
```
