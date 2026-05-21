# Pi Coding Agent — setup & resume notes

Working notes for the `add-pi` branch. This document captures the design,
the current state of the branch, and the concrete steps that remain before
it can merge to `main`. README and AGENTS.md cover the steady-state
behaviour; this file is the **bootstrap** view ("I came back a week later,
where do I pick up").

The high-level summary: replace / supplement Claude Code with [Pi Coding
Agent](https://pi.dev) on both NixOS hosts. Pi is a model-agnostic
terminal agent that lets us swap models per task, gives us the existing
Claude subscription via `/login`, and adds Cortecs.AI as an OpenAI-
compatible provider for the work models. Skills come from a pinned fork
of Felix Gladisch's repo; extensions are installed by Pi's own package
manager at runtime. Pi runs sandboxed in `nono.sh` (Landlock LSM on
Linux) via an `spi` wrapper.

The implementation mirrors the existing `claude-code` split: system
module installs the binary, home-manager owns the user-side JSON files.

## Status

What's done in this branch (`add-pi`):

- [x] `modules/development/pi-coding-agent.nix` — pi from
      `nixpkgs-unstable`
- [x] `modules/development/nono.nix` — nono.sh sandbox from
      `nixpkgs-unstable`
- [x] `modules/system/sops.nix` — sops secret `pi/cortecs_api_key`
      declared
- [x] `home/lansing/development/pi-coding-agent.nix` —
      `~/.pi/agent/{settings,models}.json`, pinned skills bundle, nono
      profile, `spi` wrapper. `rev`/`hash` for `simlans/pi-skills` are
      filled in.
- [x] Imports wired in `home/lansing/development/default.nix` and both
      `hosts/<host>/default.nix`
- [x] `AGENTS.md` updated (stack, layout, two new pitfalls)
- [x] `README.md` updated (post-install section 5)
- [x] `nix flake check --no-build` passes

What's still open before merge:

- [ ] Fork `fgladisch/pi-extensions` to `simlans/pi-extensions` on GitHub
      (only needed at `pi install` time — see "Post-rebuild" below). The
      skills fork (`simlans/pi-skills`) is already in place; that's
      where the pinned hash comes from.
- [ ] Add the **Cortecs API key** to sops. Requires either editing on a
      host that already has age-decrypt access (battlestation) **or**
      adding the Mac as a third age recipient first (see [Mac sops
      access](#mac-sops-access) below).
- [ ] `sudo nixos-rebuild test --flake .#battlestation` (and then
      `…#workstation`) — first activation. Expect to remove any
      pre-existing `~/.pi/agent/{settings,models}.json` plain files
      from a prior manual `pi` run.
- [ ] Post-rebuild per host: `pi /login`, then `pi install` the runtime
      extensions and third-party essentials (commands below).
- [ ] Update the Cortecs `models.json` entry with the actual model IDs
      the dashboard advertises — the current `openai/gpt-5` placeholder
      may not exist in the catalog.
- [ ] Commit, merge to `main`, remove worktree.

## Next steps (in order)

### 1. Fork the extension repo

```text
# On GitHub:
https://github.com/fgladisch/pi-extensions  →  Fork  →  simlans/pi-extensions
```

The fork only needs to exist; nothing pins to it from Nix. After fork,
the `pi install git:github.com/simlans/pi-extensions/packages/…` lines
in the README's post-install step (and below) will resolve.

### 2. Get the Cortecs API key into sops

Two paths depending on where you're working:

**On battlestation** (already has the `user_lansing` age key):

```bash
cd ~/Projects/nixos-workstation                 # or wherever the worktree lives
sops secrets/personal.yaml
# add at the top level, alongside existing `git:` and `sunshine:` blocks:
#   pi:
#     cortecs_api_key: <paste Cortecs key here>
```

**On the Mac**: blocked until the Mac is a sops recipient — see
[Mac sops access](#mac-sops-access).

### 3. First rebuild on each host

```bash
# Remove any pre-existing real files so home-manager can install the symlinks:
rm -f ~/.pi/agent/settings.json ~/.pi/agent/models.json

# On battlestation:
sudo nixos-rebuild test --flake ~/Projects/nixos-workstation-add-pi#battlestation
# verify, then switch:
sudo nixos-rebuild switch --flake ~/Projects/nixos-workstation-add-pi#battlestation

# Same on workstation (laptop).
```

### 4. Per-host post-rebuild bootstrap

```bash
# Bind your Claude subscription (optional but recommended):
pi
# inside pi:
/login

# Third-party essentials (Felix's recommended trio):
pi install npm:pi-mcp-adapter
pi install npm:pi-subagents
pi install npm:pi-web-access

# Felix's extensions, from your fork:
pi install git:github.com/simlans/pi-extensions/packages/pi-bash-approval
pi install git:github.com/simlans/pi-extensions/packages/pi-persistent-history
pi install git:github.com/simlans/pi-extensions/packages/pi-welcome-message
pi install git:github.com/simlans/pi-extensions/packages/pi-user-select
```

### 5. Fix up the Cortecs model list

Run `pi`, hit Ctrl+L to open the model selector, observe which Cortecs
IDs the catalog actually advertises. Then edit
`home/lansing/development/pi-coding-agent.nix`'s `models` array and
`home-manager switch` (or `nixos-rebuild switch`).

### 6. Merge

```bash
cd ~/Documents/projects/nixos-workstation
git -C ../nixos-workstation-add-pi commit -am "development: add pi coding agent + cortecs + nono sandbox"
git -C ../nixos-workstation-add-pi push -u origin add-pi
# either PR + squash on GitHub, or local merge:
git merge --no-ff add-pi
git push
git worktree remove ../nixos-workstation-add-pi
git branch -d add-pi
```

## Architecture

```
┌─ system layer (modules/development/) ───────────────────────────────┐
│  pi-coding-agent.nix → pkgs.pi-coding-agent (from nixpkgs-unstable) │
│  nono.nix            → pkgs.nono            (from nixpkgs-unstable) │
│  …both land in /run/current-system/sw/bin, available system-wide.   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─ user layer (home/lansing/development/pi-coding-agent.nix) ─────────┐
│  ~/.pi/agent/settings.json   ← read-only symlink, owned by HM       │
│  ~/.pi/agent/models.json     ← read-only symlink, owned by HM       │
│      └─ Cortecs provider, apiKey: "!cat /run/secrets/pi/cortecs_…"  │
│  ~/.pi/agent/skills/pi-skills ← symlink to fetchFromGitHub fork     │
│  ~/.config/nono/profiles/pi-dev.json ← Linux sandbox profile        │
│  PATH: spi (writeShellScriptBin → `nono run --profile pi-dev pi`)   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─ runtime / mutable state (NOT managed by Nix) ──────────────────────┐
│  ~/.pi/agent/extensions/<name>/         ← `pi install …`            │
│  ~/.pi/agent/sessions/                   ← per-cwd JSONL sessions   │
│  ~/.pi/agent/packages/                   ← pi-package-manager cache │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─ secrets ───────────────────────────────────────────────────────────┐
│  secrets/personal.yaml (sops, age-encrypted)                        │
│      pi:                                                            │
│        cortecs_api_key: …                                           │
│  /run/secrets/pi/cortecs_api_key (mode 0400, owner lansing,         │
│      mounted at activation by sops-nix)                             │
│  Pi reads it on demand via the `!cat …` shell-command syntax in     │
│  models.json — never leaks into env vars.                           │
└─────────────────────────────────────────────────────────────────────┘
```

## File map (branch diff)

| Path | Status | Purpose |
|---|---|---|
| `modules/development/pi-coding-agent.nix` | new | system package from unstable |
| `modules/development/nono.nix` | new | sandbox tool from unstable |
| `modules/system/sops.nix` | edit | declares `pi/cortecs_api_key` secret |
| `home/lansing/development/pi-coding-agent.nix` | new | user settings, models, skills, nono profile, `spi` wrapper |
| `home/lansing/development/default.nix` | edit | imports the new HM file |
| `hosts/battlestation/default.nix` | edit | imports the two new modules |
| `hosts/workstation/default.nix` | edit | imports the two new modules |
| `AGENTS.md` | edit | stack, layout, pitfalls |
| `README.md` | edit | post-install section 5 |
| `docs/pi-coding-agent.md` | new | this file |

`secrets/personal.yaml` is not in the branch yet — the sops edit
happens directly on the host that has age access, see step 2.

## Design decisions

| Concern | Decision | Why |
|---|---|---|
| Pi distribution | `pkgs.pi-coding-agent` from `nixpkgs-unstable` | Stable `release-25.11` doesn't ship it. Same pattern as `claude-code`. |
| `nono` distribution | `pkgs.nono` from `nixpkgs-unstable` | Stable doesn't ship it. On Linux it sandboxes via Landlock LSM — kernel ≥ 5.13, ours is way above. |
| Splitting `nono` and `pi-coding-agent` into separate files | Yes | AGENTS.md "one tool per file" rule. |
| System vs. user scope | System = binary only; user = settings + skills + sandbox profile + `spi` wrapper | Mirrors the `claude-code` split. |
| Skills | Declarative `fetchFromGitHub simlans/pi-skills`, pinned by rev/hash | Reproducible, follows the `oh-my-tmux` pattern in `home/lansing/shell/tmux/default.nix`. |
| Extensions | Runtime via `pi install git:github.com/simlans/pi-extensions/packages/<name>` | Pi's package manager owns the state; replicating it in Nix would mean rebuilding TypeScript at eval time. |
| Third-party essentials (`pi-mcp-adapter`, `pi-subagents`, `pi-web-access`) | Runtime via `pi install npm:<name>` | Same reasoning; npm names, not under fgladisch's scope. |
| Cortecs API key | sops secret `pi/cortecs_api_key`, read via `apiKey: "!cat /run/secrets/pi/cortecs_api_key"` | No env-var leak; resolves per request. |
| `spi` wrapper binary lookup | Bare names (`exec nono run … -- pi "$@"`), **not** `${pkgs.nono}/bin/nono` | `pi-coding-agent` and `nono` live in `nixpkgs-unstable` only; the home-manager `pkgs` is stable. Bare names resolve through `/run/current-system/sw/bin` at exec time and pick up whatever the system module installed. |
| Sandbox profile location | `~/.config/nono/profiles/pi-dev.json` via `xdg.configFile` | Matches nono's discovery path; matches Jannik Volkland's macOS pattern. |
| Documentation | README + AGENTS + this doc updated in the same change | Hard rule in AGENTS.md "Documentation upkeep". |

## Mac sops access

The Mac (this dev machine) isn't a NixOS host, so the `.sops.yaml`
recipients list doesn't include it yet. To edit secrets from the Mac
(e.g. to seed the Cortecs key without round-tripping through
battlestation), add the Mac as a third age recipient.

The private key lives in 1Password, copied to
`~/.config/sops/age/keys.txt` on the Mac.

```bash
# 1. On the Mac — generate the key:
nix-shell -p age --run "age-keygen -o ~/.config/sops/age/keys.txt"
chmod 600 ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt   # prints the public key (age1…)

# 2. Store the contents of ~/.config/sops/age/keys.txt in 1Password as a
#    Secure Note (e.g. "sops age key (mac)"). Include both lines: the
#    "# public key: age1…" comment AND the "AGE-SECRET-KEY-…" line.

# 3. Add the public key to .sops.yaml as a third recipient. Resulting
#    file roughly:
#
#    keys:
#      - &host_battlestation age1jcr…
#      - &user_lansing       age15x…
#      - &user_lansing_mac   age1<new>      # NEW
#    creation_rules:
#      - path_regex: secrets/personal\.yaml$
#        key_groups:
#          - age:
#              - *host_battlestation
#              - *user_lansing
#              - *user_lansing_mac           # NEW

# 4. On a machine that already has decrypt access (battlestation),
#    re-encrypt against the expanded recipient set:
cd ~/Projects/nixos-workstation
git pull
sops updatekeys secrets/personal.yaml
git commit -am "sops: add mac as recipient"
git push

# 5. Mac can now edit:
cd ~/Documents/projects/nixos-workstation
git pull
sops secrets/personal.yaml
```

Note: this is logically a side quest from the Pi branch. Two options:

- Bundle it: stage the `.sops.yaml` edit on `add-pi`, since the Cortecs
  key is the immediate motivation.
- Split it: separate branch `enable-mac-sops`, merge first, then come
  back to `add-pi` and seed the Cortecs key from the Mac.

Either works. The bundled path is one fewer worktree; the split path
keeps the diff per-PR cleaner.

## Verification

Static checks (run inside the worktree, work on any platform):

```bash
nix flake check --no-build

# Cortecs secret is declared on both hosts
nix eval --raw .#nixosConfigurations.battlestation.config.sops.secrets.\"pi/cortecs_api_key\".owner
nix eval --raw .#nixosConfigurations.workstation.config.sops.secrets.\"pi/cortecs_api_key\".owner
# → "lansing"

# Both packages land in environment.systemPackages
nix eval --json .#nixosConfigurations.battlestation.config.environment.systemPackages \
  --apply 'p: builtins.filter (x: builtins.match ".*(pi-coding-agent|nono).*" (x.name or "") != null) p'

# models.json renders correctly
nix eval --raw .#nixosConfigurations.battlestation.config.home-manager.users.lansing.home.file.\".pi/agent/models.json\".text
```

On-host smoke tests (after activation):

```bash
which pi spi nono                   # all three present
ls -la ~/.pi/agent/settings.json    # symlink into /nix/store
ls -la ~/.pi/agent/models.json      # symlink into /nix/store
ls -la ~/.pi/agent/skills/pi-skills # symlink to /nix/store/…-source/skills
test -r /run/secrets/pi/cortecs_api_key && echo "sops key present"
pi --version                        # 0.70.x (or newer if you bumped nixpkgs-unstable)
pi -p 'say hi'                      # one-shot; uses /login or Cortecs depending on /model
spi -p 'cat /etc/shadow'            # MUST be denied by the nono sandbox
```

## Troubleshooting

- **"Existing file is in the way"** during the first activation: home-
  manager refuses to overwrite real files at `~/.pi/agent/settings.json`
  or `~/.pi/agent/models.json`. `rm -f` them before rebuilding.
- **`fetchFromGitHub` fixed-output hash mismatch** on
  `simlans/pi-skills`: the fork was force-pushed or the `rev` is wrong.
  Re-run `nix run nixpkgs#nix-prefetch-github -- simlans pi-skills --rev main`
  and paste the new pair into `home/lansing/development/pi-coding-agent.nix`.
- **`pi` says "no API key"** even though sops shows the secret on disk:
  check that `models.json` lists `cortecs` under `providers` and that
  `apiKey` resolves (`pi /model` should not show a red badge next to
  Cortecs). The `!cat …` runs at request time; if the secret file is
  mode 0400 + owner lansing it works.
- **`spi` exits with "profile not found"**: nono looks under
  `~/.config/nono/profiles/pi-dev.json`. If the file isn't there,
  `home-manager switch` didn't complete; check for a conflicting
  real file at that path.
- **Cortecs model selector empty**: the `models` array in `models.json`
  is empty / contains only IDs the catalog rejects. Use `Ctrl+L` to see
  the live filter, edit `models.json` accordingly.
- **`pi` reports "ANTHROPIC_API_KEY not set" despite `/login`**: known
  Pi gotcha — `/login` writes to its own state dir, but some plugin
  paths still consult the env var first. Either `unset ANTHROPIC_API_KEY`
  in the session or set the explicit provider on `/model`.

## References

Slack threads (sipgate, channel `#ai`):

- [Felix's "Why I switched from Claude Code to Pi"](https://sipgate.slack.com/archives/C095R22NE2V/p1777293409032579)
- [Felix's update with skills + extensions](https://sipgate.slack.com/archives/C095R22NE2V/p1777475458569229)
- [Felix's extensions release](https://sipgate.slack.com/archives/C095R22NE2V/p1778067278570909)
- [Jannik's nono.sh + Pi on home-manager (macOS)](https://sipgate.slack.com/archives/C095R22NE2V/p1778238602633119)

Upstream repos:

- [earendil-works/pi](https://github.com/earendil-works/pi) — Pi monorepo (the coding-agent lives under `packages/coding-agent/`)
- [fgladisch/pi-skills](https://github.com/fgladisch/pi-skills) — Felix's skill library (Superpowers port + custom)
- [fgladisch/pi-extensions](https://github.com/fgladisch/pi-extensions) — Felix's extension monorepo
- [simlans/pi-skills](https://github.com/simlans/pi-skills) — our fork, pinned by `rev`/`hash` in `home/lansing/development/pi-coding-agent.nix`
- [simlans/pi-extensions](https://github.com/simlans/pi-extensions) — our fork, consumed by `pi install git:…` at runtime (not Nix-pinned)

Third-party essentials (recommended in Felix's update):

- [nicobailon/pi-subagents](https://github.com/nicobailon/pi-subagents) — multi-model subagents
- [nicobailon/pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter) — MCP bridge
- [nicobailon/pi-web-access](https://github.com/nicobailon/pi-web-access) — web search / fetch / librarian skill

Documentation:

- [Pi docs](https://pi.dev/docs/latest) — main entry point
- [Pi custom providers](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md) — how `~/.pi/agent/models.json` works
- [Pi extensions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md) — how `pi install` and the extension API works
- [Cortecs.AI docs](https://docs.cortecs.ai/) — OpenAI-compatible endpoint at `https://api.cortecs.ai/v1`
- [nono.sh docs](https://nono.sh/docs/cli/getting_started/installation) — sandbox tool (Landlock LSM on Linux, Seatbelt on macOS)
