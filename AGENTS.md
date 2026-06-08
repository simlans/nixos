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
- **`sops-nix`** (Mic92, master pin) — encrypted-at-rest secrets in `secrets/personal.yaml`, decrypted at activation into `/run/secrets/git/...` using the system's SSH host key (no separate decryption key file needed)
- **Pi coding agent** (`pi-coding-agent` from `nixpkgs-unstable`) — model-agnostic terminal coding agent. Custom Cortecs.AI provider wired up via `~/.pi/agent/models.json`; skills come from our own pinned `simlans/pi-skills` repo (not a fork of Felix's `pi-skills`); extensions are installed at runtime by Pi's own package manager. The `spi` wrapper runs Pi inside a `nono.sh` sandbox (Landlock LSM on Linux). See `docs/pi-coding-agent.md` for the bootstrap walkthrough and design decisions.

## Repo layout

```
flake.nix                                  # inputs + nixosConfigurations.{battlestation,workstation} + apps.{tailscale-up,init-account,sops-onboard-host}
.sops.yaml                                 # sops recipients (per-host SSH host pubkeys + per-user age pubkey)
secrets/personal.yaml                      # sops-encrypted YAML (git/{author_name,author_email,github_user})
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
    sops.nix                               # sops-nix wrapper: defaultSopsFile + 3 secrets owned by lansing
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
    opencloud.nix                          # opencloud-desktop (file sync client for OpenCloud servers)
  gaming/
    steam.nix                              # programs.steam + 32-bit graphics
    lutris.nix                             # lutris + umu-launcher (Lutris 0.5.20+ runs GE-Proton via UMU's Steam-runtime container; Wine-GE is EOL)
    sunshine.nix                           # services.sunshine: Moonlight game-streaming + remote desktop host (battlestation only; KMS capture, VA-API encode, sops-seeded WebUI creds)
  development/
    claude-code.nix                        # claude-code from nixpkgs-unstable
    pi-coding-agent.nix                    # pi-coding-agent from nixpkgs-unstable
    nono.nix                               # nono.sh sandbox (Landlock LSM) from nixpkgs-unstable; consumed by the `spi` wrapper
    docker.nix                             # virtualisation.docker (lansing in users.nix's groups)
home/lansing/
  default.nix                              # home-manager root: identity + imports
  cli.nix                                  # ripgrep, fd, bat, eza, jq, yq, tree, htop, file
  onepassword.nix                          # op-cache binary + IdentityAgent → 1P GUI agent
  shell/
    zsh.nix                                # zsh + oh-my-zsh + p10k + aliases + 1P signin + Alacritty auto-tmux
    p10k/p10k.zsh                          # Powerlevel10k wizard output (lean, kubecontext, 1-line)
    tmux/                                  # tmux + pinned gpakosz/.tmux + tmux.conf.local
    direnv.nix                             # direnv + nix-direnv
    fzf.nix                                # fzf + zsh integration (Ctrl+R history, Ctrl+T files, Alt+C cd)
  development/
    claude-code.nix                        # ~/.claude/settings.json (model, perms, attribution off, tmux session-state hooks)
    pi-coding-agent.nix                    # ~/.pi/agent/{settings,models}.json + pi-subagents async config + pinned simlans/pi-skills bundle + nono profile + `spi` wrapper
    git.nix                                # git + gh + delta (SSH signing on by default)
    neovim/                                # neovim + LazyVim (lazy.nvim dev path → Nix-pinned plugins, treesitter parsers prebuilt, no mason)
    kubernetes/                            # kubectl, k9s, fluxcd, talosctl + k9s skin
    golang.nix                             # go + gotools
    opentofu.nix                           # opentofu (`tofu` CLI for the homelab IaC)
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
- Plaintext secrets do not belong in this repo. Encrypted-at-rest secrets via `sops-nix` ARE supported (`secrets/personal.yaml`, host-decrypted at activation into `/run/secrets/...`); plaintext, `op://...` references in Nix-evaluated text, and other runtime-fetch patterns are not. Per-project `.envrc` files in *other* repos under `~/Projects/` may still call `op-cache read 'op://...'` — that's why `op-cache` stays in `home/lansing/onepassword.nix`'s package set even though no module in *this* repo invokes it any more.
- **Do NOT read `secrets/personal.yaml`.** It is sops/age-**encrypted ciphertext** (`ENC[AES256_GCM,...]` blocks + age headers) — there is no usable plaintext in it, so reading it yields nothing actionable. The decrypted values only exist at runtime under `/run/secrets/...`; `modules/system/sops.nix` is the map from secret name → owner. If a task needs a secret's *value*, it can't come from this file — stop and say so. (Re-reading `sops.nix`/`personal.yaml` in a loop to "understand" the secrets is a known dead end; don't.)

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

## Branching

- Any non-trivial change (new feature, refactor, anything spanning multiple files) goes on its own branch in a **separate git worktree**, so several features can be in flight in parallel without clobbering each other's `result` symlink, `.direnv/`, or half-applied edits. One-line fixes can stay on `main` in the primary checkout.
- Create the worktree as a sibling directory: `git worktree add ../nixos-<feature> -b <feature>`. Branch names are short kebab-case describing the change (`add-syncthing`, `nvidia-tweaks`, `noctalia-clock-tweaks`).
- Build and test inside the worktree (`sudo nixos-rebuild test --flake .#<host>`); each worktree gets its own `result` symlink, so concurrent builds don't fight.
- After the branch is merged into `main` (or abandoned), remove the worktree: `git worktree remove ../nixos-<feature>` and delete the branch.

## Subagent delegation

`pi-subagents` is wired to a cost-tiered Cortecs model fleet (per-role `subagents.agentOverrides` in `home/lansing/development/pi-coding-agent.nix`): cheap recon models for `scout`/`context-builder`, mid-tier coders for `worker`/`reviewer`, reasoning models for `planner`/`oracle`. The main agent (GLM-4.6) stays the orchestrator; keep it off routine work by delegating:

- **Codebase exploration / recon** (find files, entry points, data flow) → `scout`, before reading widely in the main turn.
- **Gathering context for a task** → `context-builder`.
- **Implementation** → `worker`; **review of a finished change** → `reviewer`.
- **Second opinion on a design decision** → `oracle`.

Delegated runs go to the background by default (`asyncByDefault`, see the Pi pitfall below), so recon/review doesn't block the main turn. The main agent doesn't auto-delegate on its own — this section *is* the standing instruction to do so: when working in this repo, prefer routing the work above to subagents over doing it all on the main model. Trigger it explicitly with `/run <agent> "…"`, `/chain …`, `/parallel …`, or plain prose ("use scout to …").

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
- **`users.users.lansing.description = "lansing"` is a fallback, not the real value.** The real GECOS / lock-screen name is per-machine private and lives in `/etc/nixos/local/full-name`. The activation script `applyLocalFullName` in `modules/system/users.nix` (runs after the `users` activation phase via `lib.stringAfter [ "users" ]`) reads that file and applies it via `usermod -c`, so the value survives every rebuild even though `update-users-groups.pl` rewrites `/etc/passwd` from the declarative spec on every switch (`mutableUsers = true` only protects the password column, not GECOS). Seed the file at install time via `nix run github:simlans/nixos#init-account` (the app combines `nixos-enter --root /mnt -c 'passwd lansing'` with the GECOS write to `/mnt/etc/nixos/local/full-name`, so the post-disko bootstrap is a single command). To change the value later on a running system, edit `/etc/nixos/local/full-name` directly (`sudoedit` is fine) and run `nixos-rebuild switch` — there's no separate flake app for that, since it's a one-line file edit. Don't move the value into the repo — keeping the real name out of git is the whole point. Noctalia's lock screen falls back to GECOS automatically when `NOCTALIA_REALNAME` is unset (`Services/System/HostService.qml`'s displayName chain), so `home/lansing/desktop/niri.kdl` no longer needs the env-var override.
- **`home-manager` runs as a NixOS module** (`useGlobalPkgs = true`, `useUserPackages = true`). Don't mix in standalone-mode patterns.
- **Unfree packages** (Discord, 1Password, Steam, Claude Code) require `nixpkgs.config.allowUnfree = true;` (set in `modules/system/base.nix`).
- **Git commit signing is *on* by default** with the public ed25519 key inlined in `home/lansing/git.nix`. Public keys are not secrets — committing them is the standard NixOS pattern. The matching private key never enters the repo; it lives in 1Password and gets handed to git through `~/.1password/agent.sock` at runtime. If the 1P GUI agent isn't running, signed commits simply fail until it is.
- **`programs.tmux.enable` is NOT used** — the upstream gpakosz/.tmux config sources `~/.tmux.conf.local` from `$HOME`, so we drop both files via `home.file` instead and rely on `pkgs.tmux` for the binary. Switching to `programs.tmux.enable` would generate a competing `~/.tmux.conf` and break the override mechanism.
- **`op-cache`** is a prebuilt x86_64-linux binary from `simlans/direnv-libs`. The flake evaluates fine on aarch64-darwin because nothing forces a build; the build only runs on the battlestation. Bumping the version means updating both the URL and the SRI hash in `home/lansing/onepassword.nix`. **Not in the desktop-session boot path** — `home/lansing/desktop/niri.kdl` used to spawn noctalia-shell through an `op-cache read` wrapper, which broke the whole shell when the 1P GUI hadn't started yet. The realname now flows through `/etc/passwd`'s GECOS field instead (see the `users.users.lansing.description` pitfall above). This repo no longer calls `op-cache` itself (commit identity comes from sops, see `modules/system/sops.nix`); the binary stays in `PATH` because other repos under `~/Projects/` source it from their own `.envrc` files. Don't put new `op-cache` reads in startup-critical paths.
- **`claude-code`, `pi-coding-agent`, `nono`, `lutris`, and `umu-launcher` are pulled from `nixpkgs-unstable`** (see `modules/development/{claude-code,pi-coding-agent,nono}.nix` and `modules/gaming/lutris.nix`). All five have the same "stable channel can't keep up" problem: claude-code ships hardcoded model IDs (Opus 4.7 etc.) that release-25.11's ~30-patch-behind version doesn't know about; pi-coding-agent and nono are absent from stable entirely (added to nixpkgs only after 25.11 was branched); Lutris install scripts on lutris.net pin a minimum Lutris version per game that the stable channel hasn't reached (ESO's current script requires 0.5.22; stable ships 0.5.19); umu-launcher is bumped in lockstep with Lutris because Lutris 0.5.20+ expects the newer protonfixes interface that ships in umu 1.4+. `inputs` is threaded through `specialArgs` in `flake.nix` so each module can `import inputs.nixpkgs-unstable {...}` itself with `allowUnfree = true`. Don't add further packages to this pattern unless they have the same justification — every additional consumer multiplies eval cost. `modules/gaming/lutris.nix` also carries an overlay that sets `doCheck = false` on `openldap` to dodge a flaky check-phase test (`test017-syncreplication-refresh`) that races on parallel builders — Lutris's FHS-userenv-rootfs pulls openldap in transitively, so the rebuild fails on the test. We don't run slapd here, so the lost test coverage is moot.
- **`~/.claude/settings.json` is a read-only symlink into the Nix store**, owned by `home/lansing/development/claude-code.nix`. The in-app `/config` and `/model` slash commands cannot persist changes — edit the nix file and run `home-manager switch` (or `nixos-rebuild switch`) instead. Everything else under `~/.claude/` (sessions, history, projects, plugins) stays mutable because home-manager only owns that one path. On a fresh machine the existing pre-install `~/.claude/settings.json` (if any) must be removed before the first activation, otherwise home-manager refuses to overwrite it.
- **`~/.pi/agent/{settings,models}.json`, `~/.pi/agent/extensions/subagent/config.json`, and `~/.pi/agent/skills/pi-skills/` are Nix-managed** (read-only symlinks owned by `home/lansing/development/pi-coding-agent.nix`). Same first-activation gotcha as claude-code: remove any pre-existing real files at those paths before the initial `nixos-rebuild switch`. (`extensions/subagent/config.json` carries `pi-subagents`' run-mode config — `asyncByDefault = true`, so delegated subagents run in the background. It's a *separate* file on purpose: the extension does not read async/run-mode config from `settings.json`'s `subagents` block, which only holds `agentOverrides`/`disableBuiltins`.) Everything else under `~/.pi/` (sessions, history, fetched extension code under `~/.pi/agent/npm`, prompt templates, and `~/.pi/agent/auth.json` — the `/login` OAuth token) stays mutable on purpose — Pi's package manager owns the fetched code; only the package *list* is declarative (in `settings.json`). The Claude subscription is a **built-in** Anthropic provider, so it needs no `models.json` entry (that file is only for custom providers like Cortecs); `pi /login` writes its token to `auth.json` per host, like sessions. Extensions are declared **unpinned** in `settings.json`'s `packages` list (`piPackages` in the home-manager file) and fetched by the `pi-extensions` systemd user service (`pi update --extensions` on login → always newest) into `~/.pi/agent/npm`; `pi install` can't be used on NixOS since `settings.json` is a read-only symlink. Felix's extensions are npm packages `@fgladisch/pi-*` — the `git:github.com/.../pi-extensions/packages/<name>` syntax never worked (Pi has no git-monorepo-subpath support), so the `simlans/pi-extensions` fork is unused. The Cortecs API key is sops-managed (`pi/cortecs_api_key`) and read by Pi's `apiKey: "!cat …"` shell-command directive at request time, so it never lives in an env var. Rotating it = `sops secrets/personal.yaml` + `nixos-rebuild switch`. The `simlans/pi-skills` repo (our own, not a fork of Felix's) is pinned by `rev`/`hash` in the home-manager file; bump via `nix run nixpkgs#nix-prefetch-github -- simlans pi-skills --rev main`.
- **`spi` is the sandboxed entry point** for the Pi agent (writeShellScriptBin wrapper around `nono run --profile pi-dev -- pi`); the plain `pi` binary stays in `PATH` for the unsandboxed harness. The nono profile lives at `~/.config/nono/profiles/pi-dev.json` (declared via `xdg.configFile` in `home/lansing/development/pi-coding-agent.nix`). It `extends` nono's built-in `node-dev` base (Node runtime + the conservative `default` profile) and layers on: `groups.include` `git_config`/`unlink_protection`/`user_caches_linux`; rw access to `~/.pi`, `~/.cache`, `$TMPDIR`; read access to `~/.agents`, `~/.config/git`, `/run/secrets/{pi,git}`, `/nix/store`; a `filesystem.deny` of `/var/run/docker.sock` (the real Docker gate — `commands.deny` was dropped, nono deprecated it as startup-only/bypassable and warns on every run); `network.network_profile = "developer"` plus `network.allow_domain = ["api.cortecs.ai"]` (the developer profile already covers Anthropic/OpenAI). The `spi` wrapper `chmod 700`s `~/.nono`/`~/.nono/sessions` before launch, because nono refuses to start if that dir is group/world-accessible (default `umask 022` makes it `755`). If a new model provider needs whitelisting, add its host to `network.allow_domain`. **Current nono schema** is `groups.include` + `network.allow_domain` (not the older `security.groups` / `proxy_allow`); validate edits with `nono profile validate pi-dev`. nono uses Landlock LSM on Linux (kernel ≥ 5.13, ours is well above); on macOS it uses Seatbelt. The Mac mirrors this exact profile (see `docs/pi-coding-agent-macos.md`), differing only in filesystem paths (no `/run/secrets`, `/nix/store`, or docker-sock deny) and the cache group (`user_caches_macos`). Keep the two in sync.
- **Tailscale auth key is *not* in the flake** — `services.tailscale.enable = true` only starts the daemon. First-boot bootstrap goes through the `nix run .#tailscale-up` flake app (defined in `flake.nix`); the default path runs `tailscale up` without an auth key, which prints a one-time browser login URL. The helper still accepts an auth key via stdin (`echo "$key" | nix run .#tailscale-up`) for headless setups, but the key is intentionally not stored anywhere — generate it ad-hoc at <https://login.tailscale.com/admin/settings/keys> when needed. After the join, `/var/lib/tailscale` persists the node identity and the app isn't needed again.
- **Docker group membership lives in `modules/system/users.nix`**, not in `modules/development/docker.nix`. Keeping all of `lansing`'s extraGroups in one place avoids "is the user in the right groups?" hunting across files.
- **Auto-tmux trigger keys off `$ALACRITTY_WINDOW_ID`** in `home/lansing/shell/zsh.nix`. If the daily-driver terminal changes (e.g. to foot or Ghostty), update that env-var check — otherwise zsh stops auto-attaching to the `main` session. Powerlevel10k inherits the JetBrains Nerd Font from `modules/desktop/fonts.nix`; without a Nerd Font the right-prompt icons render as tofu.
- **GNOME Keyring is wired through PAM** in `modules/desktop/keyring.nix`. `services.gnome.gnome-keyring.enable = true` plus `security.pam.services.{login,greetd,passwd}.enableGnomeKeyring = true` keeps the login keyring synced with the user account on every interactive `passwd`. Caveat: root-driven password changes (`sudo passwd <user>`, `nixos-enter -c 'passwd …'`) still bypass the sync because root never holds the old keyring password — at install time that's fine (keyring doesn't exist yet), but if you want to rotate a placeholder *after* first login, do it as the user via plain `passwd`, not via `sudo`.
- **Commit identity is forced via repo-local `.envrc`.** Home-manager writes `~/.envrc` from `home/lansing/development/git.nix`; that file `cat`s `/run/secrets/git/{author_name,author_email,github_user}` (sops-decrypted from `secrets/personal.yaml` at activation time) into `GIT_AUTHOR_*`/`GIT_COMMITTER_*`/`GITHUB_USER`. Since this repo is published publicly, a nested `.envrc` at the repo root re-exports the GitHub no-reply identity (`simlans <55317770+simlans@users.noreply.github.com>`). The Git env-vars take precedence over `git config user.email`, so without direnv-allow on this directory commits fall back to the parent's private identity and leak into history. Run `direnv allow` once after cloning, and check `git var GIT_AUTHOR_IDENT` if commits start showing up with the wrong name. The `[ -r ... ]` guard in `~/.envrc` makes it graceful before sops is bootstrapped on a host: shells start cleanly, just without the env-vars, until the host's pubkey is added to `.sops.yaml` and `secrets/personal.yaml` is re-encrypted.
- **Pre-commit hook (`gitleaks`) installs itself via `direnv` + flake devShell.** The `.envrc` runs `use flake`, which evaluates `devShells.x86_64-linux.default`; that shell's `shellHook` (provided by `git-hooks.nix`) writes `.git/hooks/pre-commit`. The hook scans staged content with `gitleaks protect --staged` and aborts the commit on a hit. `.pre-commit-config.yaml` is auto-generated on every devShell entry (it pins a Nix store path), so it's gitignored — don't commit it. After cloning, `direnv allow` once is enough; the hook is in place from the next `cd` into the repo. To run the scan manually outside of a commit: `nix flake check` builds `checks.x86_64-linux.pre-commit` which runs `pre-commit run --all-files`. Caveat: gitleaks ships allowlists for vendor-published *example* keys (e.g. AWS' `AKIAIOSFODNN7EXAMPLE`) so synthetic tests with those will pass; real-shaped keys / private-key blocks are caught.
- **Sunshine config = source of truth, WebUI is read-only when `settings` is set.** `modules/gaming/sunshine.nix` (battlestation-only) sets `services.sunshine.settings` and `services.sunshine.applications`, which the upstream nixpkgs module documents as disabling the WebUI's Apps and Configuration tabs — those panels still render but their saves are ignored. To change encoder/output/apps, edit the nix file and rebuild; don't try to mutate via WebUI. WebUI admin credentials are *not* in `settings` — they live in `secrets/personal.yaml` under `sunshine/{admin_user,admin_pass}`, and an `ExecStartPre` calls `sunshine --creds` on every start (the upstream-supported non-interactive credential path; see `nixos/tests/sunshine.nix` in nixpkgs). Per-Moonlight-client PIN pairing remains interactive because the PIN is generated client-side at runtime — that's a Moonlight protocol constraint, not a NixOS gap. KMS capture requires `capSysAdmin = true` on Niri/Wayland (not wlroots — Niri has its own compositor); VA-API via `/dev/dri/renderD128` is the supported HW encoder path on AMD (AMF isn't part of the open Linux Mesa stack). `output_name = "DP-1"` matches the niri output declared in `hosts/battlestation/default.nix` — if the host gains a second DRM output (e.g. TV on HDMI), pick per session from the Moonlight client or pin via an app's `prep-cmd`.

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

- Custom kernel builds
- nixos-anywhere for remote installs (bootstrap runs locally from the USB stick)
