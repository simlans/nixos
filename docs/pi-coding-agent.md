# Pi Coding Agent — setup & resume notes

Working notes for the `add-pi` branch. This document captures the design,
the current state of the branch, and the concrete steps that remain before
it can merge to `main`. README and AGENTS.md cover the steady-state
behaviour; this file is the **bootstrap** view ("I came back a week later,
where do I pick up").

Setting Pi up on a Mac (no Nix / no home-manager)? See the companion
walkthrough: [`pi-coding-agent-macos.md`](pi-coding-agent-macos.md).

## Keep macOS and NixOS in sync

**Rule: the two NixOS hosts and the Mac run the same Pi setup** — same models,
skills, sandbox rules, and extensions, for an identical coding experience
everywhere. **Any change here must be mirrored into the macOS setup in the same
change**, and this doc kept paired with
[`pi-coding-agent-macos.md`](pi-coding-agent-macos.md). What maps to what:

| Concern | NixOS (this file's module: `home/lansing/development/pi-coding-agent.nix`) | macOS (plain files, see the macOS doc) |
|---|---|---|
| models / providers | `home.file.".pi/agent/models.json"` | `~/.pi/agent/models.json` |
| settings | `home.file.".pi/agent/settings.json"` | `~/.pi/agent/settings.json` |
| subagent run-mode (async) | `home.file.".pi/agent/extensions/subagent/config.json"` | `~/.pi/agent/extensions/subagent/config.json` |
| skills pin | `piSkills.rev` / `hash` | `git checkout <rev>` of `simlans/pi-skills` |
| nono profile | `piNonoProfile` (paths differ per platform) | `~/.config/nono/profiles/pi-dev.json` |
| `spi` wrapper | `writeShellScriptBin "spi"` | `~/.local/bin/spi` |
| extensions (unpinned) | `piPackages` → `settings.json` + `pi-extensions` service runs `pi update --extensions` | `pi install npm:…` once, then `pi update` to refresh |
| local models / Ollama | `modules/development/ollama.nix` (`services.ollama`) + `providers.ollama` in `models.json` | the Ollama.app + `providers.ollama` in `~/.pi/agent/models.json` |

The `nono` profile uses the same schema and the same `extends: node-dev` base
on both platforms (current nono schema: `groups.include` + `network.allow_domain`).
A few things legitimately differ: the Cortecs key source (sops-nix here vs.
local file / 1Password on the Mac); the profile's filesystem paths plus cache
group (NixOS store + `/run/secrets` + docker-sock deny + `user_caches_linux`,
Landlock; vs. `$HOME/...` + `user_caches_macos`, Seatbelt); and the nono
`open_port` that opens localhost for the Ollama provider (Linux needs the
explicit `11434`, the Mac uses `0` — see "Local models (Ollama)"). Model IDs,
skill revision, the `node-dev` base, denied commands, and the allowed domain
should match. Current models: the **default is the local Ollama
`qwen3-coder-next-64k`** (see "Local models (Ollama)"). The Cortecs (EU-sovereign)
fleet stays selectable via `/model` — `qwen3-next-80b-a3b-thinking` the working
cloud fallback, `glm-4.6` (Z.ai GLM-4.6) the intended steady-state main model,
`devstral-2512` (Mistral Devstral 2 2512) also selectable — plus the open-weight
Qwen3/DeepSeek models the `pi-subagents` builtins are pinned to (see "Subagent
model overrides" in the macOS doc and `subagents.agentOverrides` in
`settings.json`).

One filesystem path is **macOS-only on purpose**: the Mac's profile adds a
`$HOME/Documents/projects/.gitconfig` read because `~/Documents/projects/.envrc`
(direnv) exports `GIT_CONFIG_GLOBAL` pointing git at that parent-directory
gitconfig, and the env var is inherited into the sandbox. NixOS has no such
redirect — git there reads `~/.gitconfig` (a `/nix/store` symlink, covered by
the `/nix/store` read + `git_config` group) and `~/.config/git` (already in the
read list), with identity coming from `~/.envrc` env vars (sops). So the NixOS
profile needs **no** equivalent read path; don't add one to keep the profiles
"in sync" — this asymmetry is intentional.

The high-level summary: replace / supplement Claude Code with [Pi Coding
Agent](https://pi.dev) on both NixOS hosts. Pi is a model-agnostic
terminal agent that lets us swap models per task, gives us the existing
Claude subscription via `/login`, and adds Cortecs.AI as an OpenAI-
compatible provider for the work models. Skills come from our own pinned
`simlans/pi-skills` repo (not a fork of Felix Gladisch's `pi-skills` — that
superpowers port is no longer used); extensions are installed by Pi's own
package manager at runtime. Pi runs sandboxed in `nono.sh` (Landlock LSM on
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

- [x] ~~Fork `fgladisch/pi-extensions`~~ — **not needed.** Felix's
      extensions install from npm (`@fgladisch/pi-*`); Pi has no
      git-monorepo-subpath support, so the planned `git:.../packages/<name>`
      installs never worked. Only the `simlans/pi-skills` repo matters (it's
      pinned by `rev`/`hash`).
- [ ] Add the **Cortecs API key** to sops. Requires either editing on a
      host that already has age-decrypt access (battlestation) **or**
      adding the Mac as a third age recipient first (see [Mac sops
      access](#mac-sops-access) below).
- [ ] `sudo nixos-rebuild test --flake .#battlestation` (and then
      `…#workstation`) — first activation. Expect to remove any
      pre-existing `~/.pi/agent/{settings,models}.json` plain files
      from a prior manual `pi` run.
- [x] Extensions automated: pinned `packages` list in `settings.json` +
      `pi-extensions` systemd user service runs `pi update --extensions`.
      Post-rebuild per host the only manual step is `pi /login` (interactive
      OAuth).
- [x] Cortecs `models.json` set to EU-sovereign models — `glm-4.6` (Z.ai
      GLM-4.6) as the default agent model, `devstral-2512` (Mistral Devstral 2
      2512) also selectable, plus the Qwen3/DeepSeek subagent fleet. Add more
      European IDs from the catalog as desired
      (`curl …/v1/models`); keep the list identical to the Mac's.
- [ ] Commit, merge to `main`, remove worktree.

## Next steps (in order)

### 1. Extensions (no fork needed)

Felix Gladisch's extensions are published to **npm** as `@fgladisch/pi-*`,
the essentials (`pi-subagents`, `pi-web-access`) are npm packages too, and so is
the rpiv set (`@juicesharp/rpiv-ask-user-question`, `rpiv-todo`, `rpiv-i18n`).
They're all declared **unpinned** in the `piPackages` list in
`home/lansing/development/pi-coding-agent.nix` and fetched automatically by the
`pi-extensions` systemd user service — nothing to do here. (`rpiv-i18n` also
reads `~/.config/rpiv-i18n/locale.json`, rendered by `xdg.configFile`.)

The originally-planned `pi install git:github.com/simlans/pi-extensions/packages/<name>`
approach **does not work**: Pi has no git-monorepo-subpath support, so it
tries to `git clone …/pi-extensions/packages/<name>` and 404s. The
`simlans/pi-extensions` fork is therefore unnecessary — ignore or delete it.

### 2. Get the Cortecs API key into sops

Two paths depending on where you're working:

**On battlestation** (already has the `user_lansing` age key):

```bash
cd ~/Projects/nixos                 # or wherever the worktree lives
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
sudo nixos-rebuild test --flake ~/Projects/nixos-add-pi#battlestation
# verify, then switch:
sudo nixos-rebuild switch --flake ~/Projects/nixos-add-pi#battlestation

# Same on workstation (laptop).
```

### 4. Per-host post-rebuild bootstrap

The **only** manual step is binding your Claude subscription:

```bash
pi
# inside pi:
/login
```

Extensions are **not** installed by hand. The `piPackages` list in
`home/lansing/development/pi-coding-agent.nix` (declared into the read-only
`settings.json`) is the source of truth, and the `pi-extensions` systemd user
service runs `pi update --extensions` on login to fetch/refresh them into the
writable `~/.pi/agent/npm`. The list is **unpinned**, so each login pulls the
latest release. To force a refresh mid-session:

```bash
systemctl --user restart pi-extensions   # or: pi update --extensions
```

(`pi install` can't be used on NixOS — it writes `settings.json`, which is a
read-only Nix symlink. And Felix's extensions are npm packages
`@fgladisch/pi-*`, not git-monorepo subpaths — see step 1.)

### 5. Cortecs model list

Cortecs serves EU-sovereign models only, and the `models` array is the
allow-list. It holds `glm-4.6` (Z.ai GLM-4.6, the default agent model) and
`devstral-2512` (Mistral Devstral 2 2512, also selectable), plus the open-weight
Qwen3/DeepSeek models the subagents are pinned to — every
model a `subagents.agentOverrides` entry references must be in this array or it
won't resolve. To add more European models, list the catalog (`curl -s https://api.cortecs.ai/v1/models
-H "Authorization: Bearer $(cat /run/secrets/pi/cortecs_api_key)" | jq '.data[].id'`
or `pi` → Ctrl+L), then edit
`home/lansing/development/pi-coding-agent.nix`'s `models` array and
`home-manager switch` (or `nixos-rebuild switch`). **Mirror the same IDs in
the Mac's `~/.pi/agent/models.json`** (see the macOS doc).

### 6. Merge

```bash
cd ~/Documents/projects/nixos
git -C ../nixos-add-pi commit -am "development: add pi coding agent + cortecs + nono sandbox"
git -C ../nixos-add-pi push -u origin add-pi
# either PR + squash on GitHub, or local merge:
git merge --no-ff add-pi
git push
git worktree remove ../nixos-add-pi
git branch -d add-pi
```

## Local models (Ollama)

Added after the initial `add-pi` work: alongside Cortecs (cloud, EU-sovereign),
Pi can talk to a **local Ollama** server for offline / zero-cost inference.
Ollama exposes an OpenAI-compatible API on `127.0.0.1:11434`, so it slots in as
a second provider with the same `api: "openai-completions"` shape as Cortecs.
**`qwen3-coder-next-64k` from this provider is now the default model**
(`defaultProvider = "ollama"` / `defaultModel` in `settings.json`); the Cortecs
fleet stays selectable via `/model`. This requires the derived model present on
the host and ~53 GB RAM (see "Per-host acceleration & VRAM").

What this adds:

- **`modules/development/ollama.nix`** — `services.ollama.enable = true`,
  imported by both hosts. Binds localhost only (no firewall hole). Models are
  **not** declared here (see the num_ctx note); they're pulled at runtime.
- **`providers.ollama`** in `home/lansing/development/pi-coding-agent.nix`'s
  `models.json` block — `baseUrl = "http://127.0.0.1:11434/v1"`, a literal dummy
  `apiKey = "ollama"` (Ollama ignores auth but Pi wants the field), and the
  local model allow-list. `127.0.0.1` not `localhost`: Ollama binds IPv4 only,
  so a `::1` first-try just adds a refused round-trip.
- **`open_port = [ 11434 ]`** in `piNonoProfile.network` — lets sandboxed `spi`
  reach Ollama. nono's `NO_PROXY` already lists localhost, so Pi/Node connects
  direct (bypassing the proxy); `open_port` opens the raw localhost socket at the
  Landlock layer. **Linux needs the explicit port; macOS uses `0`** (= all of
  `localhost:*` outbound — per-port doesn't work there), so the Mac's
  `pi-dev.json` carries `open_port: [0]` instead.

### The num_ctx gotcha (why models are *derived* tags)

Ollama caps context at **4096 tokens by default**, regardless of what the model
supports — and silently truncates the *front* of anything longer, so a coding
agent loses its system prompt + tool definitions. The OpenAI `/v1` endpoint has
no per-request `num_ctx` knob, so the fix is a **derived model tag** that bakes
the real window in:

```bash
ollama pull qwen3-coder-next
printf 'FROM qwen3-coder-next\nPARAMETER num_ctx 65536\n' | ollama create qwen3-coder-next-64k -f -
```

`models.json` then points at `qwen3-coder-next-64k` (not the bare tag); same
trick for gemma (`gemma4-12b-256k`). `services.ollama.loadModels` can't express
this, which is why models stay runtime-managed rather than declarative — pull +
derive by hand on each host (and on the Mac, see the macOS doc).

### Current local models

| id (derived tag) | base | num_ctx | notes |
|---|---|---|---|
| `qwen3-coder-next-64k` | `qwen3-coder-next` (q4_K_M, ~52 GB) | 65536 | best local coding-agent model that fits; 64K keeps it on-GPU on a 64 GB Mac (full 256K KV is too big alongside 52 GB of weights) |
| `gemma4-12b-256k` | `gemma4:12b` (q4_K_M, ~7.6 GB) | 262144 | generalist, full 256K fits easily; weak at agentic coding — a fallback, not the main model |

### Per-host acceleration & VRAM

- **battlestation** (AMD Radeon RX 9070 XT, RDNA 4 / gfx1201): the host sets
  `services.ollama.acceleration = "rocm"`. RDNA 4 ROCm support is recent — if
  `journalctl -u ollama` shows a CPU fallback, set
  `services.ollama.rocmOverrideGfx = "12.0.1"`. The card has **16 GB VRAM**, so
  the 52 GB qwen only *partially* offloads here; models that fit ~14 GB run
  fully on-GPU. A 64 GB-unified-memory Mac is the better home for the big model.
- **workstation** (Framework 13, Intel): no discrete GPU → CPU inference
  (the module default). Fine for small models; impractical for the 52 GB qwen.

The model **allow-list and IDs must match the Mac's** `~/.pi/agent/models.json`
(`providers.ollama`), same rule as the Cortecs list. The Ollama *server* and the
pulled/derived models are per-machine runtime state (like `auth.json`), not
synced — only the provider config in `models.json` is.

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
│  ~/.pi/agent/skills/pi-skills ← symlink to fetchFromGitHub repo     │
│  ~/.config/nono/profiles/pi-dev.json ← Linux sandbox profile        │
│  PATH: spi (writeShellScriptBin → `nono run --profile pi-dev pi`)   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─ runtime / mutable state (NOT managed by Nix) ──────────────────────┐
│  ~/.pi/agent/npm/                        ← extension code (npm dir) │
│  ~/.pi/agent/sessions/                   ← per-cwd JSONL sessions   │
│  ~/.pi/agent/packages/                   ← pi-package-manager cache │
│  ~/.pi/agent/auth.json                   ← pi /login OAuth token    │
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
| Extensions (essentials + Felix's) | Declared **unpinned** in `settings.json`'s `packages` (npm refs incl. `@fgladisch/pi-*`); the `pi-extensions` systemd user service runs `pi update --extensions` on login to fetch them into `~/.pi/agent/npm` | `pi install` can't run on NixOS (it writes the read-only `settings.json` symlink); declaring the list + a oneshot reconciler keeps it hands-off. Unpinned = newest on each login. Felix ships on npm — Pi has no git-monorepo-subpath support, so `git:.../packages/<name>` never worked. |
| Cortecs API key | sops secret `pi/cortecs_api_key`, read via `apiKey: "!cat /run/secrets/pi/cortecs_api_key"` | No env-var leak; resolves per request. |
| Claude subscription auth | Built-in Anthropic provider; `pi /login` writes the OAuth token to `~/.pi/agent/auth.json` (per-host, mutable, **not** Nix-managed) | Anthropic is built-in, so it needs **no** `models.json` entry — `models.json` is only for custom providers (Cortecs). Only the token differs per machine, like sessions, so it stays out of the flake. Run `pi /login` once per host. |
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
cd ~/Projects/nixos
git pull
sops updatekeys secrets/personal.yaml
git commit -am "sops: add mac as recipient"
git push

# 5. Mac can now edit:
cd ~/Documents/projects/nixos
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
  `simlans/pi-skills`: the repo was force-pushed or the `rev` is wrong.
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
- **`git` under `spi` fails with `unable to access '…/.gitconfig':
  Operation not permitted`**: this only bites if something sets
  `GIT_CONFIG_GLOBAL` (or a `gitdir:` `includeIf`) to a path **outside** the
  sandbox's read scope — e.g. a per-tree `.envrc` like the Mac's. The default
  NixOS setup doesn't, so it shouldn't occur here. If you introduce such a
  redirect, add the target file to `piNonoProfile.filesystem.read` in
  `home/lansing/development/pi-coding-agent.nix` (the Mac fixes the identical
  case with a `$HOME/Documents/projects/.gitconfig` read entry — see the macOS
  doc).
- **`git push` / `gh` under `spi` fails**: **expected, by design — the
  sandboxed agent has no push credentials.** `gh`'s config dir
  (`~/.config/gh`) is outside the Landlock read scope, and SSH is blocked by
  the network layer (the proxy isn't SSH-aware), so the `gh auth
  git-credential` helper (set in `home/lansing/development/git.nix`) can't
  authenticate and `git@github.com:` remotes don't connect. **Workflow: the agent edits and `git commit`s under
  `spi`; you `git push` from a normal shell or plain `pi`.** Keep remotes on
  HTTPS. We deliberately don't grant the sandbox a token (same posture as the
  Mac — see the macOS doc's "No `git push` / `gh` auth" note). A
  `url."https://github.com/".insteadOf` rewrite in
  `home/lansing/development/git.nix` (rendered into `~/.config/git/config`)
  auto-converts any `git@github.com:` / `ssh://git@github.com/` remote the agent
  sets back to HTTPS, so it can't strand the remote on the blocked SSH transport.
  If you ever want autonomous pushes, inject a scoped `GH_TOKEN` rather than
  opening `~/.config/gh` or the secret store.
- **Cortecs model selector empty**: the `models` array in `models.json`
  is empty / contains only IDs the catalog rejects. Use `Ctrl+L` to see
  the live filter, edit `models.json` accordingly.
- **`pi` reports "ANTHROPIC_API_KEY not set" despite `/login`**: known
  Pi gotcha — `/login` writes to its own state dir, but some plugin
  paths still consult the env var first. Either `unset ANTHROPIC_API_KEY`
  in the session or set the explicit provider on `/model`.
- **Local `ollama` provider unreachable / model selector empty**: the
  `services.ollama` unit isn't running, or no model is pulled. Check
  `systemctl status ollama` and `ollama list`. The provider points at
  `127.0.0.1:11434`; nothing answers until the service is up **and** a derived
  model exists (see "Local models (Ollama)").
- **A local model forgets its instructions / behaves erratically**: Ollama
  truncated the context. The bare tag defaults to 4096 tokens — make sure
  `models.json` points at the *derived* `…-64k` / `…-256k` tag (baked `num_ctx`),
  not the base tag.
- **Ollama runs on CPU on battlestation despite the RX 9070 XT**: RDNA 4
  (gfx1201) ROCm support is recent. Set
  `services.ollama.rocmOverrideGfx = "12.0.1"` and rebuild; confirm the HIP/ROCm
  device line in `journalctl -u ollama`. Also remember the card's 16 GB VRAM
  caps how much of a large model offloads.
- **`spi` can't reach Ollama**: `open_port = [ 11434 ]` is missing from
  `piNonoProfile.network` (on the Mac it must be `0`, not `11434`). Without it
  the sandbox blocks the localhost socket — plain `pi` still works.

## References

Slack threads (sipgate, channel `#ai`):

- [Felix's "Why I switched from Claude Code to Pi"](https://sipgate.slack.com/archives/C095R22NE2V/p1777293409032579)
- [Felix's update with skills + extensions](https://sipgate.slack.com/archives/C095R22NE2V/p1777475458569229)
- [Felix's extensions release](https://sipgate.slack.com/archives/C095R22NE2V/p1778067278570909)
- [Jannik's nono.sh + Pi on home-manager (macOS)](https://sipgate.slack.com/archives/C095R22NE2V/p1778238602633119)

Upstream repos:

- [earendil-works/pi](https://github.com/earendil-works/pi) — Pi monorepo (the coding-agent lives under `packages/coding-agent/`)
- [fgladisch/pi-skills](https://github.com/fgladisch/pi-skills) — Felix's skill library (Superpowers port + custom); **no longer used as our base** — kept here only as a reference/inspiration
- [fgladisch/pi-extensions](https://github.com/fgladisch/pi-extensions) — Felix's extension monorepo (we use only the `@fgladisch/pi-persistent-history` npm package from it)
- [simlans/pi-skills](https://github.com/simlans/pi-skills) — our own skills repo (currently just a `commit` skill), pinned by `rev`/`hash` in `home/lansing/development/pi-coding-agent.nix`
- [simlans/pi-extensions](https://github.com/simlans/pi-extensions) — our fork; **unused**. Pi can't install git-monorepo subpaths, and Felix publishes to npm; install `@fgladisch/pi-*` from npm instead.

Third-party essentials (recommended in Felix's update):

- [nicobailon/pi-subagents](https://github.com/nicobailon/pi-subagents) — multi-model subagents
- [nicobailon/pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter) — MCP bridge
- [nicobailon/pi-web-access](https://github.com/nicobailon/pi-web-access) — web search / fetch / librarian skill

Documentation:

- [Pi docs](https://pi.dev/docs/latest) — main entry point
- [Pi custom providers](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md) — how `~/.pi/agent/models.json` works
- [Pi extensions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md) — how `pi install` and the extension API works
- [Cortecs.AI docs](https://docs.cortecs.ai/) — OpenAI-compatible endpoint at `https://api.cortecs.ai/v1`
- [Cortecs glm-4.6 tool-name bug](cortecs-glm46-toolname-bug.md) — known provider bug (glm-4.6 truncates tool-call names); why the main model is temporarily `qwen3-next-80b-a3b-thinking`
- [nono.sh docs](https://nono.sh/docs/cli/getting_started/installation) — sandbox tool (Landlock LSM on Linux, Seatbelt on macOS)
- [NixOS `services.ollama`](https://search.nixos.org/options?query=services.ollama) — local Ollama server module (`enable`, `acceleration`, `rocmOverrideGfx`, `loadModels`)
- [Ollama OpenAI compatibility](https://github.com/ollama/ollama/blob/main/docs/openai.md) — the `/v1` endpoint Pi's `ollama` provider targets; [Modelfile `num_ctx`](https://github.com/ollama/ollama/blob/main/docs/modelfile.md) for the derived-tag context fix
