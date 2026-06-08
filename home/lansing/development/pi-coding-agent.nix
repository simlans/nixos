{ pkgs, osConfig, ... }:
let
  # simlans/pi-skills is our own skill repo — NOT a fork of fgladisch/pi-skills
  # (Felix's superpowers port is no longer used; the only Felix dependency left
  # is the `@fgladisch/pi-persistent-history` extension in `piPackages` below).
  # It currently holds a single `commit` skill; add more SKILL.md trees there
  # over time. Pi walks ~/.pi/agent/skills/ at startup and on /reload, so any
  # SKILL.md under the pinned tree becomes invokable as `/skill:<name>`.
  #
  # Roll forward by pushing to the repo, then re-pinning rev + hash via:
  #   nix run nixpkgs#nix-prefetch-github -- simlans pi-skills --rev main
  piSkills = pkgs.fetchFromGitHub {
    owner = "simlans";
    repo = "pi-skills";
    rev = "2eeab00942f55a4212241c872986cbe1ba1802db";
    hash = "sha256-7UHDOp+Ssab/sMUt2KeBGa0qdR952876Y0ZoSbFmL7g=";
  };

  piProfileName = "pi-dev";

  # Pi extensions, declared **unpinned** on purpose: the `pi-extensions`
  # oneshot service below runs `pi update --extensions` on login, and without
  # a version suffix npm resolves each to its latest release — so every login
  # refreshes to newest (we want current over frozen). This list is the single
  # source of truth. Two unscoped essentials (`pi-subagents`, `pi-web-access`,
  # nicobailon), one `@fgladisch/...` (Felix Gladisch's `pi-persistent-history`),
  # and the three `@juicesharp/rpiv-*` ("rpiv") set. NB: all ship on **npm**,
  # NOT installable via the old `git:github.com/.../pi-extensions/packages/<name>`
  # syntax — Pi has no git-monorepo subpath support (so the `simlans/pi-extensions`
  # fork is not needed). KEEP IN SYNC with the Mac's ~/.pi/agent/settings.json
  # (docs/pi-coding-agent-macos.md) — this list matches the Mac's exactly.
  #
  # `@juicesharp/rpiv-config` shows up under ~/.pi/agent/npm/node_modules but is
  # NOT listed here on purpose — it's a transitive dependency of the rpiv
  # extensions, not a package you install directly. `rpiv-i18n` additionally
  # reads ~/.config/rpiv-i18n/locale.json (managed via xdg.configFile below).
  piPackages = [
    "npm:pi-subagents"
    "npm:pi-web-access"
    "npm:@fgladisch/pi-persistent-history"
    "npm:@juicesharp/rpiv-ask-user-question"
    "npm:@juicesharp/rpiv-todo"
    "npm:@juicesharp/rpiv-i18n"
  ];

  # nono profile for `spi`: Pi run inside a sandbox. Extends nono's built-in
  # `node-dev` base (Node.js runtime + the conservative `default` profile that
  # already denies credentials, keychains, browser data and shell history),
  # then layers on the Pi/Cortecs specifics. Kept in lockstep with the Mac's
  # ~/.config/nono/profiles/pi-dev.json (docs/pi-coding-agent-macos.md): same
  # schema and groups — only the filesystem paths and the linux/macos cache
  # group differ. Verified valid with `nono profile validate` (current nono
  # schema: `groups.include` + `network.allow_domain`, not the older
  # `security.groups` / `proxy_allow`). Re-validate after a rebuild with
  # `nono profile validate pi-dev`.
  #
  # `network_profile = "developer"` is a nono preset covering the toolchain's
  # endpoints (npm, GitHub, the common LLM APIs incl. Anthropic/OpenAI);
  # `allow_domain` adds Cortecs on top.
  piNonoProfile = {
    extends = "node-dev";
    meta.name = piProfileName;
    workdir.access = "readwrite";

    groups.include = [
      "git_config"
      "unlink_protection"
      "user_caches_linux"
    ];

    # No `commands.deny`: nono deprecated it (startup-only, child processes
    # bypass it — not real security) and warns on every run. Docker is gated
    # the real way instead, by denying its socket below.
    filesystem = {
      deny = [ "/var/run/docker.sock" ];
      # `allow` is read+write in the current schema, so no separate `write`.
      allow = [
        "$HOME/.pi"
        "$HOME/.cache"
        "$TMPDIR"
      ];
      read = [
        "$HOME/.agents"
        "$HOME/.config/git"
        "/run/secrets/pi"
        "/run/secrets/git"
        "/nix/store"
      ];
    };

    network = {
      network_profile = "developer";
      allow_domain = [ "api.cortecs.ai" ];
    };
  };
in
{
  # Per-user Pi configuration. The binary itself comes from
  # modules/development/pi-coding-agent.nix on the system side; this file
  # owns the JSON files under ~/.pi/agent/ that we want Nix-managed
  # (settings, models, the pinned skill bundle).
  #
  # Same caveat as ~/.claude/settings.json: once managed, these become
  # read-only symlinks into /nix/store. In-app /settings / /model edits no
  # longer persist — edit this file and `home-manager switch` (or
  # `nixos-rebuild switch`) instead. Everything else under ~/.pi/
  # (sessions, history, packages installed via `pi install`, plugins)
  # stays mutable because home-manager only owns these explicit paths.

  home.packages = [
    # spi: pi inside the nono sandbox profile defined below. Naming
    # follows Jannik's gist (sclaude / spi). The plain `pi` binary stays
    # in PATH for cases where the harness needs full access.
    #
    # `nono` and `pi` are referenced by bare name (not `${pkgs.nono}/bin/...`)
    # because pi-coding-agent and nono live in `nixpkgs-unstable` only —
    # see modules/development/{pi-coding-agent,nono}.nix. They're in
    # /run/current-system/sw/bin via environment.systemPackages, so PATH
    # resolution at exec time picks up whichever version the host has.
    (pkgs.writeShellScriptBin "spi" ''
      # nono refuses to start if ~/.nono/sessions is group/world-accessible,
      # which the default umask 022 produces (755). Force 700 before launch.
      mkdir -p "$HOME/.nono/sessions"
      chmod 700 "$HOME/.nono" "$HOME/.nono/sessions" 2>/dev/null || true
      exec nono run \
        --allow-cwd \
        --profile ${piProfileName} \
        -- pi "$@"
    '')
  ];

  # `packages` is Pi's installed-extension list. On the Mac `pi install`
  # writes it; here settings.json is a read-only Nix symlink, so we declare
  # the list directly and let the `pi-extensions` service fetch the code.
  home.file.".pi/agent/settings.json".text = builtins.toJSON {
    transport = "auto";
    enableInstallTelemetry = false;
    packages = piPackages;

    # Default model, set declaratively. On the Mac you'd pick this once via
    # Ctrl+L and it sticks (mutable file); here settings.json is a read-only
    # /nix/store symlink, so an in-app pick can't persist — without these keys
    # Pi would fall back to whatever /login provided (Claude). Pin GLM-4.6 as
    # the main reasoning/coding model instead: cheaper than Devstral and far
    # more disciplined in agentic tool-loops. KEEP IN SYNC with the Mac.
    defaultProvider = "cortecs";
    defaultModel = "glm-4.6";
    defaultThinkingLevel = "medium";

    # pi-subagents per-role model overrides. Builtin subagents otherwise
    # inherit `defaultModel` (GLM-4.6) — fine, but wasteful: the cheap recon
    # roles don't need a 0.355/1.553 €/Mtok model. We pin each of the eight
    # builtins to the cheapest model that's sensible for its job (see the
    # models.json allow-list above for prices). GLM-4.6 stays the *main* model;
    # these only affect delegated child runs. Refs use the explicit
    # `cortecs/<id>` form (provider/model); bare IDs would also resolve since
    # these models are cortecs-unique, but the prefix is unambiguous.
    # `thinking` is appended as a `:level` suffix at runtime — kept low for the
    # cheap roles, high for the reasoning ones. KEEP IN SYNC with the Mac.
    subagents.agentOverrides = {
      # read & summarise — cheapest code model, no deep thinking needed
      scout = {
        model = "cortecs/qwen3-coder-30b-a3b-instruct";
        thinking = "low";
      };
      "context-builder" = {
        model = "cortecs/qwen3-coder-30b-a3b-instruct";
        thinking = "low";
      };
      # light general orchestration / web-doc research
      delegate = {
        model = "cortecs/qwen3-30b-a3b-instruct-2507";
        thinking = "low";
      };
      researcher = {
        model = "cortecs/qwen3-30b-a3b-instruct-2507";
        thinking = "low";
      };
      # code production — strong dedicated coder, cheaper than the GLM-4.6 main
      worker = {
        model = "cortecs/qwen3-coder-next";
        thinking = "medium";
      };
      reviewer = {
        model = "cortecs/qwen3-coder-next";
        thinking = "medium";
      };
      # deep reasoning
      planner = {
        model = "cortecs/qwen3-next-80b-a3b-thinking";
        thinking = "high";
      };
      # oracle: deliberately a different model family from GLM/Qwen so the
      # "second opinion" actually challenges assumptions instead of echoing them
      oracle = {
        model = "cortecs/deepseek-v3.2";
        thinking = "high";
      };
    };
  };

  # pi-subagents background execution. This optional file is the *only* place
  # the extension reads async/run-mode config from — `settings.json`'s
  # `subagents` block only takes `agentOverrides`/`disableBuiltins`, not this.
  # `asyncByDefault` makes delegated child runs execute in the background, so
  # the main agent (GLM-4.6) keeps working while the cheap recon/worker
  # subagents run — the point of routing routine work off the main model in the
  # first place. Same read-only-symlink + first-activation caveat as the JSON
  # files above (remove any pre-existing real file before the first switch).
  # KEEP IN SYNC with the Mac (docs/pi-coding-agent-macos.md).
  home.file.".pi/agent/extensions/subagent/config.json".text = builtins.toJSON {
    asyncByDefault = true;
  };

  # Cortecs custom provider (OpenAI-compatible). `apiKey: "!…"` is Pi's
  # shell-command syntax — resolved per-request from the sops-decrypted
  # file, no env-var leak. The cortecs base URL is documented at
  # https://docs.cortecs.ai/.
  #
  # Cortecs only serves EU-hosted, GDPR-compliant ("sovereign") models, so
  # this `models` array is effectively the allow-list — only what's listed
  # shows up under `/model`. Keep it to the European models we want. List the
  # live catalog with `curl -s https://api.cortecs.ai/v1/models -H "Authorization:
  # Bearer $(cat <key>)" | jq '.data[].id'`, then edit this file and
  # `home-manager switch`. Each entry only requires `id`; the rest are
  # optional overrides. KEEP IN SYNC with the Mac's ~/.pi/agent/models.json
  # (docs/pi-coding-agent-macos.md) — same model IDs on every machine.
  home.file.".pi/agent/models.json".text = builtins.toJSON {
    providers.cortecs = {
      baseUrl = "https://api.cortecs.ai/v1";
      api = "openai-completions";
      apiKey = "!cat ${osConfig.sops.secrets."pi/cortecs_api_key".path}";
      authHeader = true;
      models = [
        # Main agent model (defaultModel in settings.json). GLM-4.6 (Z.ai,
        # open-weight) — 0.355/1.553 €/Mtok, cheaper than Devstral on *both*
        # axes and far more disciplined in agentic tool-loops, so it ends the
        # degenerate "re-read the same file forever" failures a 24B dense model
        # like Devstral fell into. Self-hostable later on the B300 cluster
        # (~357B MoE, fits in ~2 B300s at FP8).
        {
          id = "glm-4.6";
          name = "GLM-4.6 (Cortecs)";
          contextWindow = 203000;
        }
        # Kept selectable under /model, but no longer the default (loop-prone).
        {
          id = "devstral-2512";
          name = "Devstral 2 2512 (Cortecs)";
          contextWindow = 262000;
        }
        # Subagent fleet — referenced by `subagents.agentOverrides` in
        # settings.json below. Listing them here is REQUIRED: the cortecs
        # provider only knows the IDs in this array (it's the allow-list), so a
        # subagent override pointing at a model that isn't declared here would
        # fail to resolve. All are EU-hosted, open-weight (no Claude/Gemini/GPT)
        # and chosen to minimise cost per role while staying self-hostable —
        # mostly Qwen3 ~30-80B MoEs. Prices verified against the live catalog
        # (curl …/v1/models) on 2026-06-07; re-check before relying on them.
        {
          id = "qwen3-coder-30b-a3b-instruct"; # 0.053/0.222 €/Mtok — scout, context-builder
          name = "Qwen3 Coder 30B-A3B (Cortecs)";
          contextWindow = 262000;
        }
        {
          id = "qwen3-30b-a3b-instruct-2507"; # 0.089/0.268 — delegate, researcher
          name = "Qwen3 30B-A3B 2507 (Cortecs)";
          contextWindow = 262000;
        }
        {
          id = "qwen3-coder-next"; # 0.15/0.8 — worker, reviewer (cheaper than Devstral)
          name = "Qwen3 Coder Next (Cortecs)";
          contextWindow = 256000;
        }
        {
          id = "qwen3-next-80b-a3b-thinking"; # 0.134/1.073 — planner (thinking model)
          name = "Qwen3 Next 80B-A3B Thinking (Cortecs)";
          contextWindow = 128000;
        }
        {
          id = "deepseek-v3.2"; # 0.266/0.444 — oracle (distinct lineage = real 2nd opinion)
          name = "DeepSeek V3.2 (Cortecs)";
          contextWindow = 163840;
        }
      ];
    };
  };

  # Skill bundle: symlink the repo's skills/ subdir into pi's discovery
  # path. Each subdirectory inside becomes a skill (SKILL.md +
  # supporting files).
  home.file.".pi/agent/skills/pi-skills".source = "${piSkills}/skills";

  # Nono profile JSON. Lives at ~/.config/nono/profiles/pi-dev.json so
  # `nono run --profile pi-dev` (i.e. the spi wrapper) picks it up.
  xdg.configFile."nono/profiles/${piProfileName}.json".text =
    builtins.toJSON piNonoProfile;

  # @juicesharp/rpiv-i18n reads its UI locale from here. Set on the Mac first
  # (~/.config/rpiv-i18n/locale.json) and mirrored into Nix for parity — German
  # UI to match the rest of the setup. KEEP IN SYNC with the Mac.
  xdg.configFile."rpiv-i18n/locale.json".text = builtins.toJSON {
    locale = "de";
  };

  # Fetch the declared extensions automatically. `pi install` can't be used
  # on NixOS (it writes settings.json, a read-only symlink here), so the list
  # lives in settings.json above and this oneshot runs `pi update
  # --extensions` to pull the missing code into the writable ~/.pi/agent/npm.
  # `--extensions` never touches the read-only pi binary; the run is
  # idempotent (a no-op once everything is present). `/login` still has to be
  # done once per host by hand — it's an interactive OAuth flow.
  systemd.user.services.pi-extensions = {
    Unit = {
      Description = "Sync declared Pi coding-agent extensions";
      # Advisory: user units can't strictly order against the system
      # network-online.target, but this nudges it later in the sequence.
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      # pi comes from the system module (nixpkgs-unstable) in
      # /run/current-system/sw/bin; user units have a minimal PATH, so call it
      # by absolute path.
      ExecStart = "/run/current-system/sw/bin/pi update --extensions";
      # Tie the unit to the package list so `home-manager switch` restarts
      # (and re-syncs) whenever the list changes.
      Environment =
        "PI_PACKAGES_HASH=${builtins.hashString "sha256" (builtins.concatStringsSep "," piPackages)}";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
