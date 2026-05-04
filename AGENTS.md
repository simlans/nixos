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

Declarative NixOS configuration for two of simlans's machines:

- **`battlestation`** — AMD desktop (Ryzen 7 9800X3D, RX 9070 XT).
- **`workstation`** — Framework 13 Pro laptop (Intel Core Ultra 7 358H / Panther Lake), with Slack added on top of the otherwise-identical module set.

Two hosts, one flake, shared modules. Host-specific deltas live under `hosts/<host>/` and `modules/desktop/laptop.nix` (the latter only imported by `workstation`). Disk layout (LUKS + ext4), system modules, and home-manager configuration all live in the repo.

## Stack

- **NixOS 25.11** (`nixos-25.11` channel, no unstable)
- **Flakes** + `nix-command` (experimental, enabled in the config)
- **`disko`** for declarative partitioning (LUKS + ext4 on NVMe)
- **`lanzaboote`** for UEFI Secure Boot (replaces `systemd-boot`, signs kernel + initrd)
- **`home-manager`** as a NixOS module (not standalone)
- **Niri** (Wayland tiler) via `programs.niri.enable`
- **`linuxPackages_latest`** instead of the channel default (RDNA 4 needs ≥ 6.14)
- **`nixos-hardware`** (`master`) — provides the `framework-intel-core-ultra-series3` module imported by `modules/desktop/laptop.nix` for the workstation laptop
- **`git-hooks.nix`** (cachix) — provides the devShell `shellHook` that installs `.git/hooks/pre-commit` (currently runs `gitleaks` on staged content; see Pitfalls)

## Repo layout

```
flake.nix                                  # inputs + nixosConfigurations.{battlestation,workstation} + apps.{tailscale-up,init-account}
disko/battlestation.nix                    # disko module: ESP + LUKS→ext4 (battlestation NVMe)
disko/workstation.nix                      # same layout as battlestation, separate file so #workstation has its own module path
hosts/battlestation/
  default.nix                              # host aggregator: imports modules + hostName + ISO keyboard + DP-1 niri output
  hardware-configuration.nix               # AMD CPU (kvm-amd, amd_pstate=active, microcode), NVMe initrd modules
hosts/workstation/
  default.nix                              # host aggregator: imports modules + laptop.nix + slack.nix + hostName + ANSI keyboard + eDP-1 niri output
  hardware-configuration.nix               # Intel CPU (kvm-intel, microcode), NVMe + thunderbolt initrd modules — placeholder, regenerate after first boot
modules/
  system/
    base.nix                               # locale, time, nix.settings, GC, zramSwap, allowUnfree
    boot.nix                               # lanzaboote, linuxPackages_latest (kernel-param policy lives in hosts/<host>/hardware-configuration.nix)
    network.nix                            # NetworkManager, bluetooth, firewall
    users.nix                              # user lansing + groups (incl. docker); password set via nixos-enter at install
    openssh.nix                            # services.openssh + authorized keys
    tailscale.nix                          # tailscaled (auth key bootstrapped manually)
  desktop/
    niri.nix                               # programs.niri + greetd + xdg.portal + xkb (layout from `lansing.desktop.keyboardLayout`)
    keyboard-layout.nix                    # `lansing.desktop.{keyboardLayout,niriOutputs}` options + TTY console keymap (iso→de, ansi→us)
    laptop.nix                             # workstation-only: nixos-hardware framework-intel-core-ultra-series3, fprintd, fwupd, thermald, lid behaviour, TLP override
    fonts.nix                              # Noto / Fira / JetBrains Nerd Fonts
    audio.nix                              # PipeWire + rtkit
    tools.nix                              # mako, wl-clipboard, grim, slurp, ...
    keyring.nix                            # gnome-keyring (Secret Service) + PAM auto-unlock + passwd sync
  apps/
    firefox.nix                            # programs.firefox + 1P extension via policy
    onepassword.nix                        # programs._1password{,-gui}
    discord.nix                            # discord (system package)
    signal.nix                             # signal-desktop (system package)
    spotify.nix                            # spotify (system package, unfree)
    slack.nix                              # slack (system package, unfree) — only imported by workstation
  gaming/
    steam.nix                              # programs.steam + 32-bit graphics
  development/
    claude-code.nix                        # claude-code from nixpkgs-unstable
    docker.nix                             # virtualisation.docker (lansing in users.nix's groups)
home/lansing/
  default.nix                              # home-manager root: identity + imports
  cli.nix                                  # ripgrep, fd, bat, eza, fzf, jq, yq, tree, htop, file
  onepassword.nix                          # op-cache binary + IdentityAgent → 1P GUI agent
  shell/
    zsh.nix                                # zsh + oh-my-zsh + p10k + aliases + 1P signin + Alacritty auto-tmux
    p10k/p10k.zsh                          # Powerlevel10k wizard output (lean, kubecontext, 1-line)
    tmux/                                  # tmux + pinned gpakosz/.tmux + tmux.conf.local
    direnv.nix                             # direnv + nix-direnv
  development/
    claude-code.nix                        # ~/.claude/settings.json (model, perms, attribution off)
    git.nix                                # git + gh + delta (SSH signing on by default)
    neovim.nix                             # neovim + dracula + nerdtree/coc/startify/snippets
    kubernetes/                            # kubectl, k9s, fluxcd + k9s skin
    golang.nix                             # go + gotools
```

Rules:
- One tool per file. Updating zsh or tmux or git should touch exactly one `.nix` file.
- The split between `modules/` and `home/lansing/` is **system-vs-user state**: anything that registers a daemon, opens a port, manages users/groups, drops a polkit policy, or owns `/etc` files goes under `modules/`; anything that's just user-level dotfiles + per-user CLI binaries lives under `home/lansing/`. Borderline cases (e.g. a CLI binary with no daemon): default to `home/lansing/`.
- Both trees use the **same category names** so a tool is findable from its concept, not its scope. `modules/<category>/` and `home/lansing/<category>/` mirror each other:
  - `system/` (modules only) — OS fundamentals (locale, boot, networking, users, ssh, …)
  - `desktop/` (modules only) — Wayland session, fonts, audio, terminal/launcher/bar tools
  - `apps/` (modules only) — general GUI apps (browser, password manager, chat clients)
  - `gaming/` (modules only) — Steam and friends
  - `development/` — dev tooling. System half (`modules/development/`) holds the daemons (Docker, …); user half (`home/lansing/development/`) holds the CLIs (git, kubectl, go, neovim, …).
  - `shell/` (home only) — zsh, tmux, direnv — anything that shapes the interactive shell session.
  Each new system module has to be imported in **both** `hosts/battlestation/default.nix` and `hosts/workstation/default.nix` (otherwise it lands on only one host and silently drifts the two configs apart). The exception is intentionally host-specific modules: `modules/desktop/laptop.nix` is workstation-only, and `modules/apps/slack.nix` is workstation-only by spec. New home-manager files get imported by their category's `default.nix` (e.g. `home/lansing/development/default.nix`).
- Secrets do not belong in this repo. Encrypted-at-rest secrets in the flake (`sops-nix`/`agenix`) are out of scope; per-project `.envrc` + `op` (1Password CLI) is the supported runtime path. Ask the user before adding any encrypted-secret tooling.

## Conventions

- 2-space indent, no tabs.
- Strings double-quoted.
- Lists/sets explicit (no `with pkgs; [ … ]` outside of package lists).
- Imports at the top of each file, then options grouped alphabetically or thematically.
- No comments that just describe "what" the code does — only "why" (background context, bug workaround, hardware-specific reasoning).
- No `mkForce`/`mkOverride` without good reason; if used, justify in a comment.
- All comments and docstrings in English.

## Commits

- **Do not add a `Co-Authored-By: Claude …` (or any other AI assistant) trailer to commits in this repo.** Commits go in under the human author's identity only. The history is public and the trailer adds nothing the diff doesn't already say. For Claude Code specifically the harness is silenced via `attribution.commit = ""` / `attribution.pr = ""` in `~/.claude/settings.json`, which is itself declared in `home/lansing/development/claude-code.nix`. Other agents (Cursor, Codex, …) honour this rule by reading AGENTS.md.

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
- Tiny generic CLI (anything you'd reach for outside dev work) → extend `home/lansing/cli.nix`.
- Dev tool (language toolchain, k8s/cloud CLI, editor extension, git helper) → new file under `home/lansing/development/<tool>.nix`, then import from `home/lansing/development/default.nix`.
- Shell-shaping tool (prompt, multiplexer, dir hook) → `home/lansing/shell/<tool>.nix` + import from `home/lansing/shell/default.nix`.

### Enable a new service
New file in the category that fits (`modules/system/`, `modules/development/`, …), then import it in **both** `hosts/battlestation/default.nix` and `hosts/workstation/default.nix` if it should run on both. Host-specific services go into the corresponding host's `default.nix` only (or, for laptop-only services, `modules/desktop/laptop.nix`). Don't squeeze it into `base.nix` — that should stay system fundamentals.

### Update inputs
```bash
nix flake update                    # all inputs
nix flake update nixpkgs            # just one
nix flake update nixpkgs-unstable   # bumps claude-code (only consumer of unstable)
```

### Refresh hardware config (after a hardware change)
```bash
sudo nixos-generate-config --show-hardware-config \
  > hosts/<host>/hardware-configuration.nix
```
Afterwards you MUST verify: `fileSystems`, `swapDevices`, `boot.initrd.luks.*` must be removed (those are owned by disko). Otherwise it collides with the disko module.

## Validation

All commands run locally (any host with Nix, or directly on either machine):

```bash
nix flake check --no-build                                            # outputs valid?
nix flake show                                                        # nixosConfigurations.{battlestation,workstation} must show up
nix eval .#nixosConfigurations.battlestation.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.workstation.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.battlestation.config.disko.devices --json | jq
nix eval .#nixosConfigurations.workstation.config.disko.devices --json  | jq

# Multi-host smoke checks (verify the two hosts haven't drifted)
nix eval --raw .#nixosConfigurations.battlestation.config.console.keyMap   # de
nix eval --raw .#nixosConfigurations.workstation.config.console.keyMap     # us
nix eval --json .#nixosConfigurations.battlestation.config.boot.kernelParams  # contains "amd_pstate=active"
nix eval --json .#nixosConfigurations.workstation.config.boot.kernelParams    # NOT containing amd_pstate
nix eval .#nixosConfigurations.workstation.config.services.tlp.enable      # false (mkForce)
nix eval .#nixosConfigurations.workstation.config.services.fprintd.enable  # true
```

On the target machine:
```bash
sudo nixos-rebuild build  --flake .#<host>     # builds, no activation
sudo nixos-rebuild switch --flake .#<host>     # activates + sets default generation
sudo nixos-rebuild test   --flake .#<host>     # activates without setting default
```

## Pitfalls

- **`hosts/workstation/hardware-configuration.nix` is a hand-written placeholder.** The Framework 13 Pro didn't physically exist when the file was committed, so it lists conservative Intel-laptop defaults. After the first boot of the laptop, run `sudo nixos-generate-config --show-hardware-config` and merge any new kernel modules / firmware bits into the file. As always, do **not** add `fileSystems` or `boot.initrd.luks.devices.*` back — disko (`disko/workstation.nix`) is authoritative.
- **`amd_pstate=active` lives in `hosts/battlestation/hardware-configuration.nix`, not in the shared `modules/system/boot.nix`.** It is AMD-specific and breaks the workstation if it bleeds into the shared module again. The Intel CPU on the workstation uses `intel_pstate`/`intel_cpufreq` automatically — no kernel-param needed there.
- **`console.keyMap` is derived from `lansing.desktop.keyboardLayout` in `modules/desktop/keyboard-layout.nix` (`iso → de`, `ansi → us`).** Don't hardcode `console.keyMap` directly in `base.nix` or anywhere else; the option is the single source of truth and drives both XKB (Wayland) and the Linux TTY console.
- **`nixos-hardware`'s `common-pc-laptop`** (transitively imported by `framework-intel-core-ultra-series3`) enables TLP by default. We force `services.tlp.enable = lib.mkForce false;` in `modules/desktop/laptop.nix` so the existing `services.power-profiles-daemon` (`modules/desktop/power.nix`) stays the single power manager — TLP and ppd refuse to coexist.
- **Framework 13 Pro BIOS uses InsydeH2O, not AMI.** Secure-Boot reset path is *Administer Secure Boot → Erase all Secure Boot Settings* (NOT the ASRock B850 path of *Custom → Clear Secure Boot Keys*). First `fwupdmgr update` may also need Secure Boot temporarily off because some EC blobs aren't db-signed.
- **Niri `output { … }` blocks aren't pinned in `home/lansing/desktop/niri.kdl` directly.** The kdl file has an `@OUTPUTS@` placeholder; the host fills it in via `lansing.desktop.niriOutputs` (battlestation: DP-1 ultrawide; workstation: eDP-1 HiDPI). Editing the kdl in place removes the placeholder and breaks templating.
- **External-monitor `output` blocks should match by EDID `"Make Model Serial"`, not by connector name** (`DP-1`, `DP-2`, …). Connector enumeration depends on which USB-C port the cable is in and on the kernel's hot-plug order; the same monitor lands on `DP-1` in one dock and on `DP-3` on a single cable. EDID is read straight from the monitor and stays stable across ports, adapters, and docks. Use `niri msg outputs` to read the identifier from the live system. Niri does **per-output workspaces by default**, so no `workspaces { … }` block is required to keep the laptop and an external monitor independent. The position field uses logical (post-scale) pixels: with eDP-1 at scale 1.5 its logical size is 1920×1280, so a monitor placed at scale 1.0 to its right starts at `x=1920`. Detailed walk-through and examples live in `README.md` under "External displays (workstation)".
- **Don't** put `fileSystems."/" = …;` (or similar) into `hardware-configuration.nix` — disko provides those. Otherwise the flake fails to evaluate or you get duplicate mountpoints.
- **`programs.niri.package`** shouldn't be overridden without a reason — the nixpkgs module handles Wayland/polkit/portal wiring.
- **`boot.kernelPackages = pkgs.linuxPackages_latest;`** is intentional; reverting it to the channel default risks black-screen on the RX 9070 XT (RDNA 4 < kernel 6.14 is a gamble).
- **`boot.lanzaboote.enable = true;`** replaces `systemd-boot` — don't re-enable `boot.loader.systemd-boot.enable`, the two are mutually exclusive. Lanzaboote provides its own systemd-boot stub. `autoGenerateKeys` + `autoEnrollKeys` (with default `includeMicrosoftKeys = true`) handle key provisioning on first boot; the firmware must be in **Setup Mode** at that point or auto-enrollment silently does nothing.
- **`users.mutableUsers = true;`** is intentional — the user password is set during install via `sudo nixos-enter --root /mnt -c 'passwd lansing'` (after `disko-install`, before reboot), not from the repo. Don't add `initialPassword` or `hashedPassword`: both land in the world-readable Nix store.
- **`users.users.lansing.description = "lansing"` is a fallback, not the real value.** The real GECOS / lock-screen name is per-machine private and lives in `/etc/nixos/local/full-name`. The activation script `applyLocalFullName` in `modules/system/users.nix` (runs after the `users` activation phase via `lib.stringAfter [ "users" ]`) reads that file and applies it via `usermod -c`, so the value survives every rebuild even though `update-users-groups.pl` rewrites `/etc/passwd` from the declarative spec on every switch (`mutableUsers = true` only protects the password column, not GECOS). Seed the file at install time via `nix run github:simlans/nixos-workstation#init-account` (the app combines `nixos-enter --root /mnt -c 'passwd lansing'` with the GECOS write to `/mnt/etc/nixos/local/full-name`, so the post-disko bootstrap is a single command). To change the value later on a running system, edit `/etc/nixos/local/full-name` directly (`sudoedit` is fine) and run `nixos-rebuild switch` — there's no separate flake app for that, since it's a one-line file edit. Don't move the value into the repo — keeping the real name out of git is the whole point. Noctalia's lock screen falls back to GECOS automatically when `NOCTALIA_REALNAME` is unset (`Services/System/HostService.qml`'s displayName chain), so `home/lansing/desktop/niri.kdl` no longer needs the env-var override.
- **`home-manager` runs as a NixOS module** (`useGlobalPkgs = true`, `useUserPackages = true`). Don't mix in standalone-mode patterns.
- **Unfree packages** (Discord, 1Password, Steam, Claude Code) require `nixpkgs.config.allowUnfree = true;` (set in `modules/system/base.nix`).
- **Git commit signing is *on* by default** with the public ed25519 key inlined in `home/lansing/git.nix`. Public keys are not secrets — committing them is the standard NixOS pattern. The matching private key never enters the repo; it lives in 1Password and gets handed to git through `~/.1password/agent.sock` at runtime. If the 1P GUI agent isn't running, signed commits simply fail until it is.
- **`programs.tmux.enable` is NOT used** — the upstream gpakosz/.tmux config sources `~/.tmux.conf.local` from `$HOME`, so we drop both files via `home.file` instead and rely on `pkgs.tmux` for the binary. Switching to `programs.tmux.enable` would generate a competing `~/.tmux.conf` and break the override mechanism.
- **`op-cache`** is a prebuilt x86_64-linux binary from `simlans/direnv-libs`. The flake evaluates fine on aarch64-darwin because nothing forces a build; the build only runs on the battlestation. Bumping the version means updating both the URL and the SRI hash in `home/lansing/onepassword.nix`. **Not in the desktop-session boot path** — `home/lansing/desktop/niri.kdl` used to spawn noctalia-shell through an `op-cache read` wrapper, which broke the whole shell when the 1P GUI hadn't started yet. The realname now flows through `/etc/passwd`'s GECOS field instead (see the `users.users.lansing.description` pitfall above). Remaining `op-cache` callers in `home/lansing/development/git.nix` only run when a new shell starts; a failure there breaks at most a commit, not the session. Don't put new `op-cache` reads in startup-critical paths.
- **`claude-code` is the only package pulled from `nixpkgs-unstable`** (see `modules/development/claude-code.nix`). The 25.11 release branch lags ~30 patch versions behind upstream and ships without the latest model IDs (Opus 4.7 etc.), which the CLI hardcodes. `inputs` is threaded through `specialArgs` in `flake.nix` so the module can `import inputs.nixpkgs-unstable {...}` itself with `allowUnfree = true`. Don't add other packages to this pattern unless they have the same "stable channel can't keep up" problem — every additional consumer multiplies eval cost.
- **`~/.claude/settings.json` is a read-only symlink into the Nix store**, owned by `home/lansing/development/claude-code.nix`. The in-app `/config` and `/model` slash commands cannot persist changes — edit the nix file and run `home-manager switch` (or `nixos-rebuild switch`) instead. Everything else under `~/.claude/` (sessions, history, projects, plugins) stays mutable because home-manager only owns that one path. On a fresh machine the existing pre-install `~/.claude/settings.json` (if any) must be removed before the first activation, otherwise home-manager refuses to overwrite it.
- **Tailscale auth key is *not* in the flake** — `services.tailscale.enable = true` only starts the daemon. First-boot bootstrap goes through the `nix run .#tailscale-up` flake app (defined in `flake.nix`); it prompts for the key on a TTY or reads it from stdin so `op read 'op://nixos/tailscale-nixos-authkey/credential' | nix run .#tailscale-up` works. After the join, `/var/lib/tailscale` persists the node identity and the app isn't needed again.
- **Docker group membership lives in `modules/system/users.nix`**, not in `modules/development/docker.nix`. Keeping all of `lansing`'s extraGroups in one place avoids "is the user in the right groups?" hunting across files.
- **Auto-tmux trigger keys off `$ALACRITTY_WINDOW_ID`** in `home/lansing/shell/zsh.nix`. If the daily-driver terminal changes (e.g. to foot or Ghostty), update that env-var check — otherwise zsh stops auto-attaching to the `main` session. Powerlevel10k inherits the JetBrains Nerd Font from `modules/desktop/fonts.nix`; without a Nerd Font the right-prompt icons render as tofu.
- **GNOME Keyring is wired through PAM** in `modules/desktop/keyring.nix`. `services.gnome.gnome-keyring.enable = true` plus `security.pam.services.{login,greetd,passwd}.enableGnomeKeyring = true` keeps the login keyring synced with the user account on every interactive `passwd`. Caveat: root-driven password changes (`sudo passwd <user>`, `nixos-enter -c 'passwd …'`) still bypass the sync because root never holds the old keyring password — at install time that's fine (keyring doesn't exist yet), but if you want to rotate a placeholder *after* first login, do it as the user via plain `passwd`, not via `sudo`.
- **Commit identity is forced via repo-local `.envrc`.** The author uses a parent `~/Documents/projects/.envrc` that exports `GIT_AUTHOR_*`/`GIT_COMMITTER_*` from 1Password (private name + email). Since this repo is published publicly, a nested `.envrc` at the repo root re-exports the GitHub no-reply identity (`simlans <55317770+simlans@users.noreply.github.com>`). The Git env-vars take precedence over `git config user.email`, so without direnv-allow on this directory commits fall back to the parent's private identity and leak into history. Run `direnv allow` once after cloning, and check `git var GIT_AUTHOR_IDENT` if commits start showing up with the wrong name.
- **Pre-commit hook (`gitleaks`) installs itself via `direnv` + flake devShell.** The `.envrc` runs `use flake`, which evaluates `devShells.x86_64-linux.default`; that shell's `shellHook` (provided by `git-hooks.nix`) writes `.git/hooks/pre-commit`. The hook scans staged content with `gitleaks protect --staged` and aborts the commit on a hit. `.pre-commit-config.yaml` is auto-generated on every devShell entry (it pins a Nix store path), so it's gitignored — don't commit it. After cloning, `direnv allow` once is enough; the hook is in place from the next `cd` into the repo. To run the scan manually outside of a commit: `nix flake check` builds `checks.x86_64-linux.pre-commit` which runs `pre-commit run --all-files`. Caveat: gitleaks ships allowlists for vendor-published *example* keys (e.g. AWS' `AKIAIOSFODNN7EXAMPLE`) so synthetic tests with those will pass; real-shaped keys / private-key blocks are caught.

## Hardware (quick ref)

### battlestation

| Component | Model | Linux note |
|---|---|---|
| CPU | AMD Ryzen 7 9800X3D (Zen 5) | `kvm-amd`, `amd_pstate=active` |
| GPU | AMD Radeon RX 9070 XT (RDNA 4) | kernel ≥ 6.14 mandatory, `amdgpu` loads via udev (post-initrd) |
| Mainboard | ASRock B850 Riptide WiFi | Realtek 2.5G LAN, MediaTek RZ717 (= MT7925 + BT) |
| OS disk | Samsung 970 EVO Plus 500 GB NVMe | `/dev/nvme0n1` (the only NVMe present during install) |
| 2nd disk | Corsair MP600 | removed at install; later Windows; dual-boot via BIOS picker |

### workstation

| Component | Model | Linux note |
|---|---|---|
| Chassis | Framework 13 Pro (Series 3) | InsydeH2O BIOS, fwupd-managed BIOS + EC firmware |
| CPU | Intel Core Ultra 7 358H (Panther Lake) | `kvm-intel`, Intel microcode; `intel_pstate` automatic |
| GPU | Intel Arc Graphics (integrated, Panther Lake) | `i915`/`xe` driver; mainline kernel ≥ 6.16 recommended |
| RAM | 64 GB LPCAMM2 LPDDR5X | — |
| OS disk | Phison PS5031-E31T 2 TB PCIe 5.0 NVMe | `/dev/nvme0n1` (only M.2 slot on the FW13 Pro) |
| Display | 2.8K touchscreen, 120 Hz | niri `scale 1.5`; libinput handles touch out of the box |
| Wi-Fi / BT | (Framework default — Intel BE201 / AX210) | iwd backend in NetworkManager |
| Ethernet | WisdPi 10G via USB-C expansion card | chipset TBD — `lsusb` from the install USB; likely Aquantia `atlantic` (mainline) |
| Fingerprint | Goodix sensor | `services.fprintd` + PAM hooks for login + sudo (laptop.nix) |
| Keyboard | ANSI / US, Graphite | `lansing.desktop.keyboardLayout = "ansi"` (drives XKB + TTY) |

## Out of scope (for now)

- Encrypted-at-rest secrets in the flake (`sops-nix`/`agenix`) — runtime secrets via `op` + `direnv` are supported; everything else needs an explicit OK
- Custom kernel builds
- nixos-anywhere for remote installs (bootstrap runs locally from the USB stick)
