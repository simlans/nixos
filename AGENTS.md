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
  system/
    base.nix                               # locale, time, nix.settings, GC, zramSwap, allowUnfree
    boot.nix                               # lanzaboote, linuxPackages_latest, amd_pstate
    network.nix                            # NetworkManager, bluetooth, firewall
    users.nix                              # user lansing + initialPassword + groups (incl. docker)
    openssh.nix                            # services.openssh + authorized keys
    tailscale.nix                          # tailscaled (auth key bootstrapped manually)
  desktop/
    niri.nix                               # programs.niri + greetd + xdg.portal + xkb
    fonts.nix                              # Noto / Fira / JetBrains Nerd Fonts
    audio.nix                              # PipeWire + rtkit
    tools.nix                              # alacritty, fuzzel, waybar, swaylock, mako, ...
  apps/
    firefox.nix                            # programs.firefox
    onepassword.nix                        # programs._1password{,-gui}
    discord.nix                            # discord (system package)
  gaming/
    steam.nix                              # programs.steam + 32-bit graphics
  development/
    claude-code.nix                        # claude-code (system package)
    docker.nix                             # virtualisation.docker (lansing in users.nix's groups)
home/lansing/
  default.nix                              # home-manager root: identity + imports
  cli.nix                                  # ripgrep, fd, bat, eza, fzf, jq, yq, tree, htop, file
  zsh.nix                                  # zsh + oh-my-zsh + plugins + aliases + 1P signin
  tmux/                                    # tmux + pinned gpakosz/.tmux + tmux.conf.local
  direnv.nix                               # direnv + nix-direnv
  git.nix                                  # git + gh + delta (signing setup is opt-in, see file)
  neovim.nix                               # neovim + dracula + nerdtree/coc/startify/snippets
  kubernetes/                              # kubectl, k9s, fluxcd + k9s skin
  golang.nix                               # go + gotools
  onepassword.nix                          # op-cache binary + IdentityAgent → 1P GUI agent
```

Rules:
- One tool per file. Updating zsh or tmux or git should touch exactly one `.nix` file.
- System-level modules go under `modules/<category>/<tool>.nix` with these categories:
  - `system/` — OS fundamentals (locale, boot, networking, users, ssh, daemons that aren't tied to a UX)
  - `desktop/` — Wayland session, fonts, audio, terminal/launcher/bar tools
  - `apps/` — general GUI apps (browser, password manager, chat clients)
  - `gaming/` — Steam and friends
  - `development/` — dev tooling that needs system-level wiring (Docker, language daemons, …)
  Each new module also has to be imported in `hosts/battlestation/default.nix`.
- User-specific program config goes in `home/lansing/<tool>.nix` (home-manager), NOT in `modules/`.
- Secrets do not belong in this repo. Encrypted-at-rest secrets in the flake (`sops-nix`/`agenix`) are out of scope; per-project `.envrc` + `op` (1Password CLI) is the supported runtime path. Ask the user before adding any encrypted-secret tooling.

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
Pick the right category and create or extend a per-tool file:
- OS toolbox / sysadmin CLIs → `modules/system/base.nix`
- Wayland / DE helpers → `modules/desktop/tools.nix`
- New GUI app (browser, chat, password manager, …) → new `modules/apps/<name>.nix`
- Game launcher → `modules/gaming/<name>.nix`
- Dev daemon / runtime that needs system-level wiring → `modules/development/<name>.nix`

Don't mix categories in one file — one tool per file is the convention.

### Add a package only for user `lansing`
Either extend `home/lansing/cli.nix` (small CLI tools) or create a per-tool file in `home/lansing/<tool>.nix` and import it from `home/lansing/default.nix`.

### Enable a new service
New file in the category that fits (`modules/system/`, `modules/development/`, …), then import it in `hosts/battlestation/default.nix`. Don't squeeze it into `base.nix` — that should stay system fundamentals.

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
- **Unfree packages** (Discord, 1Password, Steam, Claude Code) require `nixpkgs.config.allowUnfree = true;` (set in `modules/system/base.nix`).
- **Git commit signing** in `home/lansing/git.nix` is shipped *off* — the public ed25519 key is a placeholder. Filling in the real key (and flipping `signByDefault = true`) is part of the post-install bootstrap, not a build-time step. Don't try to read it from 1Password at evaluation time; the `op` CLI is only available on the activated system.
- **`programs.tmux.enable` is NOT used** — the upstream gpakosz/.tmux config sources `~/.tmux.conf.local` from `$HOME`, so we drop both files via `home.file` instead and rely on `pkgs.tmux` for the binary. Switching to `programs.tmux.enable` would generate a competing `~/.tmux.conf` and break the override mechanism.
- **`op-cache`** is a prebuilt x86_64-linux binary from `simlans/direnv-libs`. The flake evaluates fine on aarch64-darwin (Mac) because nothing forces a build; the build only runs on the battlestation. Bumping the version means updating both the URL and the SRI hash in `home/lansing/onepassword.nix`.
- **Tailscale auth key is *not* in the flake** — `services.tailscale.enable = true` only starts the daemon. The first `tailscale up --auth-key=…` is a manual post-install step (the key comes from 1Password vault `nixos`, item `tailscale-authkey`). After that, `/var/lib/tailscale` persists the node identity across rebuilds.
- **Docker group membership lives in `modules/system/users.nix`**, not in `modules/development/docker.nix`. Keeping all of `lansing`'s extraGroups in one place avoids "is the user in the right groups?" hunting across files.

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
- Encrypted-at-rest secrets in the flake (`sops-nix`/`agenix`) — runtime secrets via `op` + `direnv` are supported; everything else needs an explicit OK
- Custom kernel builds
- nixos-anywhere for remote installs (bootstrap runs locally from the USB stick)
