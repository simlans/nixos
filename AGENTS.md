# AGENTS.md

Context for AI coding agents (Claude Code, Cursor, Codex, etc.) working on this repo. Human onboarding lives in [README](./README.md).

## Documentation language

**All documentation in this repo (README, AGENTS, code comments, commit messages) is written in English.** Don't switch to German even if the user prompts in German — keep the artifacts English so the public repo stays internationally readable.

## Documentation upkeep

**Every change that affects how the system is set up, installed, configured, recovered, or operated MUST also update the docs in the same change.** Specifically:

- New install step, BIOS/firmware prerequisite, or post-install action → update `README.md` (the user-facing first-time install / operation flow).
- New module, convention, pitfall, or stack component → update `AGENTS.md` (this file).
- Even small additions (new flake input, new system package with non-obvious purpose) deserve at least a one-line mention in the layout or stack list.

Don't wait to be asked. If you change behaviour and skip the doc update, the change is incomplete.

## What is this?

Declarative NixOS configuration for the workstation `battlestation`. A single flake describing this one host — no multi-host setup. Disk layout (LUKS + ext4), system modules, and home-manager configuration all live in the repo.

## Stack

- **NixOS 25.11** (`nixos-25.11` channel, no unstable)
- **Flakes** + `nix-command` (experimental, enabled in the config)
- **`disko`** for declarative partitioning (LUKS + ext4 on NVMe)
- **`lanzaboote`** for UEFI Secure Boot (replaces `systemd-boot`, signs kernel + initrd)
- **`home-manager`** as a NixOS module (not standalone)
- **Niri** (Wayland tiler) via `programs.niri.enable`
- **`linuxPackages_latest`** instead of the channel default (RDNA 4 needs ≥ 6.14)

## Repo layout

```
flake.nix                                  # inputs + nixosConfigurations.battlestation
disko/battlestation.nix                    # disko module: ESP + LUKS→ext4
hosts/battlestation/
  default.nix                              # host aggregator (imports modules + sets hostName)
  hardware-configuration.nix               # hardware modules + nixpkgs.hostPlatform
modules/
  system/{base,boot,network,users}.nix     # system-wide modules, importable
  desktop/niri.nix                         # Niri + greetd + PipeWire + xdg-portals
  desktop/apps.nix                         # Firefox, 1Password (GUI+CLI), Steam, Discord
home/lansing/default.nix                   # home-manager config for user `lansing`
```

Rules:
- New system modules go in `modules/system/<name>.nix`, then get imported in `hosts/battlestation/default.nix`.
- Desktop/UX stuff goes in `modules/desktop/<name>.nix`.
- User-specific program config goes in `home/lansing/`, NOT in `modules/`.
- Secrets do not belong in this repo (it's public). If that ever becomes necessary: `sops-nix` or `agenix`, ask the user first.

## Conventions

- 2-space indent, no tabs.
- Strings double-quoted.
- Lists/sets explicit (no `with pkgs; [ … ]` outside of package lists).
- Imports at the top of each file, then options grouped alphabetically or thematically.
- No comments that just describe "what" the code does — only "why" (background context, bug workaround, hardware-specific reasoning).
- No `mkForce`/`mkOverride` without good reason; if used, justify in a comment.
- All comments and docstrings in English.

## Common tasks

### Add a system-wide package
Edit `modules/system/base.nix` → extend `environment.systemPackages`. For DE-specific packages (Wayland tools etc.), prefer `modules/desktop/niri.nix` or `modules/desktop/apps.nix`.

### Add a package only for user `lansing`
Edit `home/lansing/default.nix` → extend `home.packages`.

### Enable a new service
New file in `modules/system/` or `modules/desktop/`, then import it in `hosts/battlestation/default.nix`. Don't squeeze it into `base.nix` — that should stay system fundamentals.

### Update inputs
```bash
nix flake update                    # all inputs
nix flake update nixpkgs            # just one
```

### Refresh hardware config (after a hardware change)
```bash
sudo nixos-generate-config --show-hardware-config \
  > hosts/battlestation/hardware-configuration.nix
```
Afterwards you MUST verify: `fileSystems`, `swapDevices`, `boot.initrd.luks.*` must be removed (those are owned by disko). Otherwise it collides with the disko module.

## Validation

All commands run locally (Mac with Nix or directly on the battlestation):

```bash
nix flake check --no-build                                            # outputs valid?
nix flake show                                                        # nixosConfigurations.battlestation must show up
nix eval .#nixosConfigurations.battlestation.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.battlestation.config.disko.devices --json | jq
```

On the battlestation:
```bash
sudo nixos-rebuild build  --flake .#battlestation       # builds, no activation
sudo nixos-rebuild switch --flake .#battlestation       # activates + sets default generation
sudo nixos-rebuild test   --flake .#battlestation       # activates without setting default
```

## Pitfalls

- **Don't** put `fileSystems."/" = …;` (or similar) into `hardware-configuration.nix` — disko provides those. Otherwise the flake fails to evaluate or you get duplicate mountpoints.
- **`programs.niri.package`** shouldn't be overridden without a reason — the nixpkgs module handles Wayland/polkit/portal wiring.
- **`boot.kernelPackages = pkgs.linuxPackages_latest;`** is intentional; reverting it to the channel default risks black-screen on the RX 9070 XT (RDNA 4 < kernel 6.14 is a gamble).
- **`boot.lanzaboote.enable = true;`** replaces `systemd-boot` — don't re-enable `boot.loader.systemd-boot.enable`, the two are mutually exclusive. Lanzaboote provides its own systemd-boot stub. `autoGenerateKeys` + `autoEnrollKeys` (with default `includeMicrosoftKeys = true`) handle key provisioning on first boot; the firmware must be in **Setup Mode** at that point or auto-enrollment silently does nothing.
- **`users.mutableUsers = true;`** is intentional — the user password is set with `passwd` after first boot, not in the repo. Don't add `initialPassword`.
- **`home-manager` runs as a NixOS module** (`useGlobalPkgs = true`, `useUserPackages = true`). Don't mix in standalone-mode patterns.
- **Unfree packages** (Discord, 1Password, Steam) require `nixpkgs.config.allowUnfree = true;` (set in `modules/system/base.nix`).

## Hardware (quick ref)

| Component | Model | Linux note |
|---|---|---|
| CPU | AMD Ryzen 7 9800X3D (Zen 5) | `kvm-amd`, `amd_pstate=active` |
| GPU | AMD Radeon RX 9070 XT (RDNA 4) | kernel ≥ 6.14 mandatory, `amdgpu` loads via udev (post-initrd) |
| Mainboard | ASRock B850 Riptide WiFi | Realtek 2.5G LAN, MediaTek RZ717 (= MT7925 + BT) |
| OS disk | Samsung 970 EVO Plus 500 GB NVMe | `/dev/nvme0n1` (the only NVMe present during install) |
| 2nd disk | Corsair MP600 | removed at install; later Windows; dual-boot via BIOS picker |

## Out of scope (for now)

- Multi-host setup (only `battlestation` exists)
- Secrets management (`sops-nix`/`agenix`) — if needed, coordinate with user first
- Custom kernel builds
- nixos-anywhere for remote installs (bootstrap runs locally from the USB stick)
