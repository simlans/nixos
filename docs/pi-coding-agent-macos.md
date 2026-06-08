# Pi Coding Agent on macOS — step-by-step

This is the macOS companion to [`pi-coding-agent.md`](pi-coding-agent.md).
That document describes how Pi is wired up on the two **NixOS** hosts, where
Nix installs the binaries and home-manager owns every config file. This
machine is a plain Mac — **no Nix, no home-manager, no sops-nix** — so the
same end state has to be assembled by hand. Nothing here touches the flake;
it only produces files under `~/.pi/` and `~/.config/nono/` locally.

If you feel overwhelmed: you don't. The NixOS side just bundles a handful of
small steps into one `nixos-rebuild`. Below they're spelled out one at a
time. Work top to bottom; each step is independent enough to stop and resume.

## Keep macOS and NixOS in sync

**Rule: the Mac and the two NixOS hosts run the same Pi setup.** The goal is an
identical coding experience everywhere — same models, same skills, same sandbox
rules, same extensions. So **any change you make on one side, mirror on the
other in the same change**, and keep this doc paired with
[`pi-coding-agent.md`](pi-coding-agent.md). Drift (a model here, a skill there)
defeats the point.

What lives where:

| Concern | macOS (plain files, this doc) | NixOS (`home/lansing/development/pi-coding-agent.nix`) |
|---|---|---|
| models / providers | `~/.pi/agent/models.json` | `home.file.".pi/agent/models.json"` |
| settings | `~/.pi/agent/settings.json` | `home.file.".pi/agent/settings.json"` |
| skills pin | `git checkout <rev>` of `simlans/pi-skills` | `piSkills.rev` / `hash` |
| nono profile | `~/.config/nono/profiles/pi-dev.json` | `piNonoProfile` (paths differ per platform) |
| `spi` wrapper | `~/.local/bin/spi` | `writeShellScriptBin "spi"` |
| extensions (unpinned) | `pi install npm:…` once, `pi update` to refresh | `piPackages` → `settings.json` + `pi-extensions` service |
| subagent models | `subagents.agentOverrides` in `settings.json` | same block in `home.file.".pi/agent/settings.json"` |
| subagent run-mode (async) | `~/.pi/agent/extensions/subagent/config.json` | `home.file.".pi/agent/extensions/subagent/config.json"` |
| rpiv-i18n locale | `~/.config/rpiv-i18n/locale.json` | `xdg.configFile."rpiv-i18n/locale.json"` |

Two things genuinely *can't* be byte-identical and that's expected: the Cortecs
key source (local file / 1Password on the Mac vs. sops-nix on NixOS) and the
`nono` profile's filesystem paths (`$HOME/...` + Seatbelt on macOS vs. NixOS
store / `/run/secrets` + Landlock). Everything else — model IDs, skill
revision, denied commands, allowed domains, extension list — should match.

## What the NixOS setup does, and the macOS equivalent

| Concern | On NixOS (the flake) | On macOS (this guide) |
|---|---|---|
| `pi` binary | `pkgs.pi-coding-agent` from `nixpkgs-unstable`, system-wide | `curl` installer or `npm -g` |
| `nono` sandbox binary | `pkgs.nono` from `nixpkgs-unstable`, system-wide | `brew install nono` |
| `~/.pi/agent/settings.json` | home-manager symlink (read-only) | a plain file you write (**mutable**) |
| `~/.pi/agent/models.json` (Cortecs provider) | home-manager symlink | a plain file you write |
| Cortecs API key | sops-nix → `/run/secrets/pi/cortecs_api_key`, read via `!cat …` | a local `chmod 600` file (or 1Password), read via `!cat …` |
| Skills | `fetchFromGitHub simlans/pi-skills`, pinned by `rev`/`hash` | `git clone` of the same repo at the same rev |
| `nono` profile (`pi-dev`) | `xdg.configFile` → `~/.config/nono/profiles/pi-dev.json` | scaffolded with `nono profile init`, written to the same path |
| `spi` wrapper | `writeShellScriptBin` on `PATH` | a small shell script on your `PATH` |
| Extensions (`pi install …`) | runtime, not in Nix | **identical** — runtime, same commands |

Two real differences to keep in mind on macOS:

1. **Nothing is read-only here.** On NixOS the config files are `/nix/store`
   symlinks, so in-app `/settings` and `/model` edits don't persist. On the
   Mac they're ordinary files — in-app edits stick, and you edit them with a
   normal editor.
2. **The sandbox is enforced differently.** `nono` uses Apple's Seatbelt on
   macOS instead of Linux's Landlock. Filesystem and command rules behave the
   same, but network policy is enforced through a localhost proxy, and the
   profile schema has moved on a little since the Linux profile in this repo
   was written (see [Step 6](#6-create-the-nono-sandbox-profile)). That's why
   we scaffold a fresh profile here rather than copying the Linux JSON.

## Prerequisites

- [Homebrew](https://brew.sh) installed.
- The `simlans/pi-skills` repo exists (you've done this) — our own skills repo
  (just a `commit` skill, not a fork of Felix's `pi-skills`); it's pinned by
  `rev`/`hash` and consumed at build time. The
  `simlans/pi-extensions` fork turned out **not** to be needed (Felix's
  extensions install from npm, see Step 9), so you can ignore or delete it.
- Your Cortecs API key from <https://cortecs.ai> (optional — only needed for
  the Cortecs provider; `/login` against your Claude subscription works
  without it).

## 1. Install `pi`

Either installer is fine; the `curl` one is self-contained and the simplest:

```bash
curl -fsSL https://pi.dev/install.sh | sh
```

Or, if you'd rather go through npm:

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

Verify:

```bash
pi --version
```

To update later: re-run the installer, or `npm update -g @earendil-works/pi-coding-agent`.

## 2. Install `nono`

```bash
brew install nono
nono --version          # confirm it's on PATH
```

`nono` is what powers the `spi` wrapper (Step 7) — `pi` run inside a sandbox.
If you only want plain `pi` for now you can skip nono and come back; the
agent works fine without it, just without the guard rails.

## 3. Write `settings.json`

```bash
mkdir -p ~/.pi/agent
cat > ~/.pi/agent/settings.json <<'JSON'
{
  "transport": "auto",
  "enableInstallTelemetry": false
}
JSON
```

This is the minimal starting point. The `defaultProvider` / `defaultModel` /
`defaultThinkingLevel` keys (set by the in-app model pick in Step 9) and the
`subagents.agentOverrides` block (Step 10) bring it to parity with what the
flake renders on the NixOS hosts.

## 4. Provide the Cortecs API key

On NixOS this comes from sops-nix at `/run/secrets/pi/cortecs_api_key`. There
is no sops-nix here, so pick one of:

**Option A — local file (recommended, simplest).** A plain file with tight
permissions, read on demand by Pi's `!cat …` directive (Step 5):

```bash
printf '%s' 'PASTE_YOUR_CORTECS_KEY_HERE' > ~/.pi/agent/cortecs_api_key
chmod 600 ~/.pi/agent/cortecs_api_key
```

`~/.pi` is inside the sandbox's allowed paths, so `spi` can still read it.

**Option B — 1Password (tidier, optional).** If you keep the key in 1Password
and have the `op` CLI, you can skip the on-disk file and use
`"!op read op://Private/Cortecs/api_key"` as the `apiKey` in Step 5 instead.
Caveat: `op` needs network + your 1Password session, which the `nono` sandbox
restricts — this works under plain `pi` but may need extra `allow_domain`
entries (or just use it unsandboxed) under `spi`. Start with Option A unless
you specifically want this.

## 5. Write `models.json` (the Cortecs provider)

Cortecs only serves EU-hosted, GDPR-compliant ("sovereign") models, so the
catalog is a curated subset — not every model you'd find elsewhere exists
here. The `models` array below is effectively your **allow-list**: only the
IDs you list show up under `/model`, so keep it to the European models you
actually want. The main agent model is Z.ai's **GLM-4.6** (`glm-4.6`) — cheaper
than Devstral on both axes and far steadier in agentic tool-loops; **Devstral 2
2512** (`devstral-2512`) stays selectable for comparison. The rest of the array
is the open-weight Qwen3/DeepSeek fleet the subagents are pinned to (Step 10) —
every model a `subagents.agentOverrides` entry references must be listed here or
it won't resolve. Reproduce the full list from the nix file
(`home/lansing/development/pi-coding-agent.nix`) so the Mac matches the hosts:

```bash
cat > ~/.pi/agent/models.json <<'JSON'
{
  "providers": {
    "cortecs": {
      "baseUrl": "https://api.cortecs.ai/v1",
      "api": "openai-completions",
      "apiKey": "!cat ~/.pi/agent/cortecs_api_key",
      "authHeader": true,
      "models": [
        { "id": "glm-4.6", "name": "GLM-4.6 (Cortecs)", "contextWindow": 203000 },
        { "id": "devstral-2512", "name": "Devstral 2 2512 (Cortecs)", "contextWindow": 262000 },
        { "id": "qwen3-coder-30b-a3b-instruct", "name": "Qwen3 Coder 30B-A3B (Cortecs)", "contextWindow": 262000 },
        { "id": "qwen3-30b-a3b-instruct-2507", "name": "Qwen3 30B-A3B 2507 (Cortecs)", "contextWindow": 262000 },
        { "id": "qwen3-coder-next", "name": "Qwen3 Coder Next (Cortecs)", "contextWindow": 256000 },
        { "id": "qwen3-next-80b-a3b-thinking", "name": "Qwen3 Next 80B-A3B Thinking (Cortecs)", "contextWindow": 128000 },
        { "id": "deepseek-v3.2", "name": "DeepSeek V3.2 (Cortecs)", "contextWindow": 163840 }
      ]
    }
  }
}
JSON
```

`apiKey` is Pi's shell-command syntax: the `!…` part runs at request time, so
the key never lands in an env var. If you chose Option B in Step 4, swap the
`!cat …` value for your `!op read …` command.

These are the exact IDs Cortecs expects (verified against its catalog; Devstral
also has a lighter `devstral-small-2512`). To see every EU model on offer and
add more to the allow-list, query the catalog —
`curl -s https://api.cortecs.ai/v1/models -H "Authorization: Bearer $(cat ~/.pi/agent/cortecs_api_key)" | jq '.data[].id'`
— or browse <https://cortecs.ai/serverlessModels>, then add the IDs you want
to the `models` array. The default model itself is picked in Step 9.

## 6. Add the skills bundle

The NixOS side pins `simlans/pi-skills` by `rev`/`hash`. Reproduce the exact
same revision so this Mac matches the hosts. Pi discovers any `SKILL.md`
under `~/.pi/agent/skills/`.

```bash
git clone https://github.com/simlans/pi-skills.git ~/Documents/projects/pi-skills
git -C ~/Documents/projects/pi-skills checkout 2eeab00942f55a4212241c872986cbe1ba1802db
mkdir -p ~/.pi/agent/skills
ln -sfn ~/Documents/projects/pi-skills/skills ~/.pi/agent/skills/pi-skills
```

Notes:
- The `mkdir -p` is required — `ln` fails with "No such file or directory" if
  `~/.pi/agent/skills/` doesn't exist yet.
- The symlink target is the repo's `skills/` **subdirectory** (the Nix file
  points at that same subdir), and it must be an **absolute** path.
- `-sfn` makes re-running idempotent (replaces the link if it already exists).

To roll skills forward later: `git -C ~/Documents/projects/pi-skills checkout
main && git -C ~/Documents/projects/pi-skills pull` — and, to keep the Mac and
the NixOS hosts in lockstep, bump the pinned `rev`/`hash` in
`home/lansing/development/pi-coding-agent.nix` to the same commit.

## 7. Create the `nono` sandbox profile

A `nono` profile is a ready-made sandbox policy. `extends: "<base>"` inherits
all of a base profile's rules, then you override/add only your specifics. List
the bases your `nono` actually ships with via `nono profile list` — the set
depends on the version. (Older nono docs and even `nono`'s own help text
mention a `claude-code` base; **that profile isn't shipped in current nono
versions** — it's just an example, and has nothing to do with Anthropic's
Claude Code tool. Don't extend it; it won't resolve.)

Pi is a Node app (installed via npm), so the right base is **`node-dev`** — it
extends nono's conservative `default` (which already denies access to
credentials, keychains, browser data, and shell history) and adds the Node.js
runtime group plus the `developer` network profile. We layer on top: read/write
to `~/.pi`, the Cortecs domain, a few coding-agent groups, and Docker denials.

Scaffold, then overwrite `~/.config/nono/profiles/pi-dev.json` with:

```bash
nono profile init pi-dev --extends node-dev
```

```json
{
  "extends": "node-dev",
  "meta": {
    "name": "pi-dev",
    "description": "Pi coding agent sandbox (macOS)"
  },
  "workdir": { "access": "readwrite" },
  "groups": {
    "include": ["git_config", "unlink_protection", "user_caches_macos"]
  },
  "filesystem": {
    "allow": ["$HOME/.pi", "$HOME/.cache", "$TMPDIR"],
    "read":  ["$HOME/.agents", "$HOME/.config/git", "$HOME/Documents/projects/.gitconfig"]
  },
  "network": {
    "network_profile": "developer",
    "allow_domain": ["api.cortecs.ai"]
  }
}
```

Validate and inspect the resolved policy before relying on it:

```bash
nono profile validate ~/.config/nono/profiles/pi-dev.json   # → "Result: valid"
nono profile show pi-dev          # expands `extends` + groups so you see the real rules
```

Notes:

- This profile is verified against nono 0.61.x (`validate` → valid, `show`
  resolves 22 security groups). `filesystem.allow` is read+write in the current
  schema, so the three rw paths need no separate `write` list.
- `$HOME/Documents/projects/.gitconfig` in the **read** list is macOS-only and
  exists because `~/Documents/projects/.envrc` (direnv, auto-loaded for every
  subdirectory) exports `GIT_CONFIG_GLOBAL="$HOME/Documents/projects/.gitconfig"`.
  That env var is inherited into the sandbox, so any `git` invocation under `spi`
  reads the *parent-directory* gitconfig as its global config. Without this read
  path git fails with `fatal: unable to access
  '…/projects/.gitconfig': Operation not permitted`. It's a single read-only
  file (identity, signing key, `gpgsign`), so granting read is least-privilege.
  Confirm it resolved with `nono profile show pi-dev | grep gitconfig` and that
  git works with `nono run --allow-cwd --profile pi-dev -- git config --get user.email`.
  (Signed *commits* additionally need the 1Password SSH agent + `op-ssh-sign`,
  which the sandbox doesn't grant — run those under plain `pi`, or extend the
  profile separately. Reading the config for `git status`/`log` works as-is.)
- **No `git push` / `gh` auth from inside `spi` — by design.** The `node-dev`
  base inherits nono's `default` deny on credentials and the macOS **Keychain**,
  which is exactly where both git's `osxkeychain` helper
  (`/opt/homebrew/etc/gitconfig`) and `gh` keep the GitHub token (`gh`'s
  `hosts.yml` stores it as `keyring`, not in the file). So HTTPS pushes can't
  retrieve the token, and switching the remote to SSH doesn't help either —
  nono's network proxy isn't SSH-aware, so `git@github.com:` is blocked
  outright. **Intended workflow: let the agent edit and `git commit` under
  `spi`, then `git push` from a normal shell or plain `pi`** (full Keychain
  access). Keep remotes on **HTTPS** (`https://github.com/...`) and don't let
  the agent rewrite them to `git@github.com:`. We deliberately do **not** inject
  a token into the sandbox (the alternative — a scoped PAT via `GH_TOKEN` from
  1Password at `spi` launch — was considered and rejected to keep zero push
  credentials in the sandbox).
- **Guard against SSH-rewrites.** Because a coding agent tends to "fix" a
  failing push by switching `origin` to `git@github.com:`, `~/Documents/projects/
  .gitconfig` carries a `[url "https://github.com/"]` block with
  `insteadOf = git@github.com:` and `insteadOf = ssh://git@github.com/`. Git
  then resolves any GitHub SSH URL back to HTTPS, so the agent can't strand the
  remote on the proxy-blocked SSH transport. It's the `GIT_CONFIG_GLOBAL` file,
  so it's read inside the sandbox too. NixOS mirrors this in
  `home/lansing/development/git.nix` (`programs.git.settings.url`), rendered into
  `~/.config/git/config`. Verify with `git ls-remote --get-url
  git@github.com:owner/repo.git` → it prints the `https://` form.
- `network_profile: "developer"` already covers the LLM/package/GitHub
  endpoints (Anthropic and OpenAI included); `allow_domain` adds Cortecs on top.
  On macOS nono enforces this via a localhost proxy — it applies to proxy-aware
  tools; anything that ignores the proxy is blocked outright.
- **No `commands.deny`.** nono deprecated it (startup-only — child processes
  bypass it, so it's not real security) and warns about it on every run. We
  rely on filesystem/network policy instead. On the NixOS side Docker is gated
  the real way, by denying its socket (`/var/run/docker.sock`); that path
  doesn't exist on macOS, and the sandbox doesn't grant the Docker socket
  anyway, so there's nothing to add here.
- **In sync with NixOS:** the repo's Linux profile (`piNonoProfile` in
  `home/lansing/development/pi-coding-agent.nix`) uses the **same** schema and
  the same `extends: node-dev` base, validated identically. Only the filesystem
  paths and the cache group differ by necessity: the NixOS side adds
  `/run/secrets/{pi,git}` + `/nix/store` reads and the `/var/run/docker.sock`
  deny and uses `user_caches_linux`; this Mac uses `user_caches_macos` and adds
  the `$HOME/Documents/projects/.gitconfig` read (macOS-only, see the bullet
  above — NixOS has no `GIT_CONFIG_GLOBAL` parent-config redirect, so it needs
  no equivalent). Everything else — base, groups, allowed domain — matches.
  Change one side, change the other.

## 8. Add the `spi` wrapper

The NixOS `spi` is a tiny script that runs `pi` inside the sandbox. Recreate it
on your `PATH`:

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/spi <<'SH'
#!/bin/sh
# nono refuses to start if ~/.nono/sessions is group/world-accessible, which
# the default umask 022 produces (755). Force 700 before launching.
mkdir -p "$HOME/.nono/sessions"
chmod 700 "$HOME/.nono" "$HOME/.nono/sessions" 2>/dev/null || true
exec nono run \
  --allow-cwd \
  --profile pi-dev \
  -- pi "$@"
SH
chmod +x ~/.local/bin/spi
```

(The `mkdir`/`chmod` guard is also in the NixOS `spi` wrapper — `nono` errors
out with *"`~/.nono/sessions` must not be group/world accessible"* on the first
run otherwise, since the default `umask 022` creates that directory `755`.)

Make sure `~/.local/bin` is on your `PATH` (add to `~/.zshrc` if needed):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
exec zsh
```

Now `spi` == sandboxed Pi, `pi` == unsandboxed full-access Pi (use the latter
only when the sandbox gets in the way).

## 9. First run, login, and extensions

```bash
# Bind your Claude subscription (recommended):
pi
# inside pi:
/login

# Essentials (nicobailon) + Felix Gladisch's + the rpiv (@juicesharp) set —
# all from npm, unpinned so you always get the latest release:
pi install npm:pi-subagents
pi install npm:pi-web-access
pi install npm:@fgladisch/pi-persistent-history
pi install npm:@juicesharp/rpiv-ask-user-question
pi install npm:@juicesharp/rpiv-todo
pi install npm:@juicesharp/rpiv-i18n
```

`@juicesharp/rpiv-i18n` reads its UI language from
`~/.config/rpiv-i18n/locale.json`. Create it once (German, to match the rest of
the setup); on NixOS this is rendered by `xdg.configFile."rpiv-i18n/locale.json"`:

```bash
mkdir -p ~/.config/rpiv-i18n
printf '%s\n' '{ "locale": "de" }' > ~/.config/rpiv-i18n/locale.json
```

(`@juicesharp/rpiv-config` may also appear under `~/.pi/agent/npm/node_modules`
— that's a transitive dependency of the rpiv extensions, not something you
install directly, so it's not in the `packages` list.)

To refresh them to the newest versions later, run `pi update --extensions`
(or `pi update`, which also updates Pi itself).

> **Felix's extensions come from npm, not a git monorepo.** The earlier
> `pi install git:github.com/simlans/pi-extensions/packages/<name>` form does
> **not** work — Pi has no git-monorepo-subpath support, so it tries to clone
> `…/pi-extensions/packages/<name>` as a repo and gets a 404. Felix publishes
> each extension to npm as `@fgladisch/pi-<name>`, which is what we install
> above. (So the `simlans/pi-extensions` fork isn't needed for installs — see
> Prerequisites.)

`pi install` records each package in `~/.pi/agent/settings.json`'s `packages`
array and downloads the code to `~/.pi/agent/npm/`. On the **NixOS hosts** you
don't run these commands at all: the `packages` list is declared in
`home/lansing/development/pi-coding-agent.nix` and a `pi-extensions` systemd
user service runs `pi update --extensions` to fetch them automatically (only
`/login` stays manual there). Keep this list and that Nix list identical.

### Why the Claude login isn't in `models.json`

`/login` runs an OAuth flow against Anthropic and writes the token to
`~/.pi/agent/auth.json` — that's a **credential**, not a provider definition.
Anthropic/Claude is a **built-in** provider (Pi already ships its endpoint and
model list), so once `auth.json` holds the token, the Claude models show up
under `/model` automatically — **no `models.json` entry needed**. You'd only
add Anthropic to `models.json` to *override* it (custom baseUrl, a proxy, etc.).

`models.json` is exclusively for providers Pi *doesn't* know out of the box
(Cortecs) plus their API keys (the `!cat …` directive). So the split is:

- **Claude** → built-in provider + credential in `auth.json` (via `/login`)
- **Cortecs** → custom provider declared in `models.json` + `apiKey`

Press **Ctrl+L** and you'll see both.

`auth.json` is machine-local and secret — like sessions and installed
extensions, it's intentionally **not** synced or Nix-managed. Run `/login`
**once per machine** (here, and on each NixOS host). The synced part is the
*configuration* (`models.json`, `settings.json`, skills, nono profile); the
*credentials and state* stay per-machine.

Then pick the model: run `pi`, press **Ctrl+L**, and select
**GLM-4.6 (Cortecs)** (the default agent model; Devstral 2 2512 stays selectable
for comparison). To offer more European models, add their IDs to
the `models` array in `~/.pi/agent/models.json` (Step 5 shows how to list the
catalog). On macOS this file is mutable, so edits just stick — no rebuild
needed.

## 10. Subagent model overrides

`pi-subagents` ships eight builtin agents (`scout`, `context-builder`,
`delegate`, `researcher`, `worker`, `reviewer`, `planner`, `oracle`). By default
they all inherit `defaultModel` (GLM-4.6) — correct but wasteful, since the
cheap recon roles don't need a 0.355/1.553 €/Mtok model. We pin each role to the
cheapest model that's sensible for its job via `subagents.agentOverrides` in
`settings.json`. **GLM-4.6 stays the main agent's model**; these only affect
delegated child runs. All picks are EU-hosted, open-weight (no Claude/Gemini/GPT)
and mostly self-hostable Qwen3 MoEs:

| Role | Model | €/Mtok in/out | Why |
|---|---|---|---|
| scout, context-builder | `qwen3-coder-30b-a3b-instruct` | 0.053 / 0.222 | cheap, fast code read+summarise |
| delegate, researcher | `qwen3-30b-a3b-instruct-2507` | 0.089 / 0.268 | light general/research, tools |
| worker, reviewer | `qwen3-coder-next` | 0.15 / 0.8 | strong coder, cheaper than Devstral |
| planner | `qwen3-next-80b-a3b-thinking` | 0.134 / 1.073 | thinking model for plans |
| oracle | `deepseek-v3.2` | 0.266 / 0.444 | different lineage = a real second opinion |

Every model referenced here must also be in the `models.json` allow-list
(Step 5) — the cortecs provider only knows the IDs you list, so an override
pointing at an undeclared model won't resolve. The `model` value uses the
explicit `cortecs/<id>` form; bare IDs also resolve since these models are
cortecs-unique, but the prefix is unambiguous. `thinking` is appended as a
`:level` suffix at runtime (kept `low` for the cheap roles, `high` for the
reasoning ones). Override a single run instead with
`/run reviewer[model=cortecs/qwen3-coder-next:high] "…"`. List live prices with
`curl -s https://api.cortecs.ai/v1/models -H "Authorization: Bearer $(cat
~/.pi/agent/cortecs_api_key)" | jq '.data[] | {id, pricing}'`.

## 11. Subagent background execution

`asyncByDefault` makes delegated subagents run in the background by default, so
the main agent keeps working while `scout`/`worker`/`reviewer` run instead of
blocking the turn. `pi-subagents` reads this from its **own** config file — *not*
`settings.json`'s `subagents` block (that only takes `agentOverrides`). On NixOS
it's the read-only `home.file.".pi/agent/extensions/subagent/config.json"`; on
the Mac it's a plain file:

```bash
mkdir -p ~/.pi/agent/extensions/subagent
cat > ~/.pi/agent/extensions/subagent/config.json <<'JSON'
{
  "asyncByDefault": true
}
JSON
```

The extension also accepts `forceTopLevelAsync`, `parallel.{maxTasks,concurrency}`
(default 8 / 4), `maxSubagentDepth`, and `intercomBridge` here — defaults are
fine; add them only to tune fan-out limits. Keep this file identical on the
NixOS hosts (the nix `home.file` above renders the same JSON).

## Verify

```bash
which pi spi nono                       # all three on PATH
pi --version
ls -l ~/.pi/agent/settings.json         # plain file
ls -l ~/.pi/agent/models.json           # plain file
ls -l ~/.pi/agent/skills/pi-skills      # symlink → ~/Projects/pi-skills/skills
test -r ~/.pi/agent/cortecs_api_key && echo "cortecs key present"
nono profile show pi-dev                # resolved sandbox policy

pi -p 'say hi'                          # one-shot; uses /login or Cortecs per /model
spi -p 'cat /etc/passwd'                # runs, but writes outside the cwd/allowed paths are denied
```

## Troubleshooting

- **`pi: command not found` after install** — the npm/curl install dir isn't on
  `PATH`. For npm: `echo $(npm config get prefix)/bin`; add it to `~/.zshrc`.
- **`spi` says "profile not found"** — the file must be at
  `~/.config/nono/profiles/pi-dev.json`. Re-check Step 7 and run
  `nono profile show pi-dev`.
- **`nono: … ~/.nono/sessions must not be group/world accessible`** — the
  default `umask 022` created it `755`. Fix once with
  `chmod 700 ~/.nono ~/.nono/sessions`; the `spi` wrapper (Step 8) does this
  automatically on every launch.
- **`nono profile validate` rejects a key** — the schema moved since the Linux
  profile was written. Dump the live schema with
  `nono profile schema --output /tmp/nono.schema.json` and align your keys
  (`groups.include`, `network.allow_domain`, …).
- **Pi says "no API key" for Cortecs** — confirm `~/.pi/agent/cortecs_api_key`
  exists, is `chmod 600`, and that the `!cat …` path in `models.json` matches
  it exactly. The command runs at request time; a missing/empty file shows as a
  red badge next to Cortecs under `/model`.
- **Cortecs model selector empty** — the `models` array only lists IDs the
  catalog rejects. Use **Ctrl+L** to see the live filter and edit
  `models.json` (Step 9).
- **`/login` works but Pi still wants `ANTHROPIC_API_KEY`** — a stray env var is
  taking precedence. `unset ANTHROPIC_API_KEY` in the session, or pick the
  explicit provider under `/model`.
- **Cortecs unreachable only under `spi`** — the sandbox is doing its job;
  confirm `api.cortecs.ai` is in `network.allow_domain` and visible in
  `nono profile show pi-dev`. Test the same command under plain `pi` to
  confirm it's a sandbox issue and not a key/model issue.
- **`git` under `spi` fails with `unable to access
  '…/Documents/projects/.gitconfig': Operation not permitted`** — `~/Documents/
  projects/.envrc` sets `GIT_CONFIG_GLOBAL` to that parent-directory gitconfig
  and the env var is inherited into the sandbox, but the file is outside the
  allowed read paths. Add `$HOME/Documents/projects/.gitconfig` to
  `filesystem.read` (Step 7), then `nono profile validate
  ~/.config/nono/profiles/pi-dev.json` and re-run. NixOS doesn't hit this — it
  has no such `GIT_CONFIG_GLOBAL` redirect.
- **`git push` / `gh` under `spi` fails** (`Please make sure you have the
  correct access rights`, `gh ... operation not permitted`, `could not lock
  config file`) — **expected, not a bug.** The sandbox denies Keychain access,
  so neither git's `osxkeychain` helper nor `gh` can reach the GitHub token, and
  SSH is proxy-blocked. Don't switch the remote to SSH and don't try to write
  global git config from inside the sandbox. Commit under `spi`, then **push
  from a normal shell or plain `pi`.** A GitHub SSH remote the agent may have
  set is auto-rewritten to HTTPS by the `[url].insteadOf` guard (Step 7), so it
  no longer strands the remote on the blocked SSH transport — tidy it up anyway
  with `git remote set-url origin https://github.com/<owner>/<repo>.git` if you
  like. See the "No `git push` / `gh` auth" note in Step 7 for the rationale.

## References

Everything in the [main doc's References section](pi-coding-agent.md#references)
applies. macOS-specific:

- [Pi install (macOS)](https://pi.dev/docs/latest)
- [nono install (Homebrew)](https://nono.sh/docs/cli/getting_started/installation)
- [nono profiles & groups](https://nono.sh/docs/cli/features/profiles-groups.md)
- [nono profile authoring / validation](https://nono.sh/docs/cli/features/profile-authoring.md)
- [nono networking (proxy / domain filtering)](https://nono.sh/docs/cli/features/networking.md)
- [nono on macOS (Seatbelt internals)](https://nono.sh/docs/cli/internals/seatbelt.md)
