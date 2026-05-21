{ pkgs, osConfig, ... }:
let
  # simlans/pi-skills is a fork of fgladisch/pi-skills (Felix Gladisch's
  # adapted superpowers + subagent-aware versions). Pi walks
  # ~/.pi/agent/skills/ at startup and on /reload, so any SKILL.md under
  # the pinned tree becomes invokable as `/skill:<name>`. Bump rev + hash
  # to roll forward.
  #
  # Bootstrap: after forking on GitHub, populate `rev` and `hash` via
  #   nix run nixpkgs#nix-prefetch-github -- simlans pi-skills --rev main
  # The placeholder values below intentionally fail the fixed-output
  # derivation so a build error surfaces the missing step.
  piSkills = pkgs.fetchFromGitHub {
    owner = "simlans";
    repo = "pi-skills";
    rev = "04a078621a88be4509c4ca07d02dac901d1d775f";
    hash = "sha256-cvq4+14YxSE5mfF6N+VG5J/kWK/zHosdB4+rLrjlViw=";
  };

  piProfileName = "pi-dev";

  # Linux nono profile for `spi`. Adapted from Jannik Volkland's macOS
  # gist (sipgate Slack, see plan file); same shape, but paths point at
  # NixOS-native locations and the sops mounts the agent reads from.
  #
  # `network_profile = "developer"` is a nono preset that allows the
  # toolchain (npm, pip, etc.) network access; we narrow further via
  # `proxy_allow` to the LLM endpoints we actually use.
  piNonoProfile = {
    meta.name = piProfileName;
    interactive = true;
    workdir.access = "readwrite";

    security.groups = [
      "node_runtime"
      "unlink_protection"
    ];

    commands.deny = [
      "docker"
      "docker-compose"
      "podman"
      "kubectl"
      "k9s"
    ];

    filesystem = {
      deny = [ "/var/run/docker.sock" ];
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
      write = [
        "$HOME/.pi"
        "$HOME/.cache"
        "$TMPDIR"
      ];
    };

    network = {
      network_profile = "developer";
      proxy_allow = [
        "127.0.0.1"
        "localhost"
        "api.cortecs.ai"
        "api.anthropic.com"
        "api.openai.com"
      ];
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
      exec nono run \
        --allow-cwd \
        --profile ${piProfileName} \
        -- pi "$@"
    '')
  ];

  home.file.".pi/agent/settings.json".text = builtins.toJSON {
    transport = "auto";
    enableInstallTelemetry = false;
  };

  # Cortecs custom provider (OpenAI-compatible). `apiKey: "!…"` is Pi's
  # shell-command syntax — resolved per-request from the sops-decrypted
  # file, no env-var leak. The cortecs base URL is documented at
  # https://docs.cortecs.ai/.
  #
  # `models` is a starter list. After bootstrap, run `pi` → Ctrl+L to see
  # which Cortecs IDs the catalog actually advertises, then edit this
  # file and `home-manager switch`. Each entry only requires `id`; the
  # remaining fields are optional overrides.
  home.file.".pi/agent/models.json".text = builtins.toJSON {
    providers.cortecs = {
      baseUrl = "https://api.cortecs.ai/v1";
      api = "openai-completions";
      apiKey = "!cat ${osConfig.sops.secrets."pi/cortecs_api_key".path}";
      authHeader = true;
      models = [
        {
          id = "openai/gpt-5";
          name = "GPT-5 (Cortecs)";
          contextWindow = 200000;
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
}
