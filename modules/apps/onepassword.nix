{
  flake.modules.nixos.desktop = { config, ... }: {
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      # Every interactive user of the host gets 1Password polkit access — not a
      # single hard-coded user. my.homeUsers is the host's full user list.
      polkitPolicyOwners = config.my.homeUsers;
    };

    # Route SSH through 1Password's agent. pam_gnome_keyring.so otherwise
    # exports SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh at session start, which
    # squats on every shell and breaks `git commit` (SSH-signed) since
    # gnome-keyring's agent has no keys. The 1P agent socket is created by
    # the GUI when "Use SSH agent" is enabled in 1Password → Developer.
    environment.sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";

    host.desktop.niri.appWindowRules = [
      # Route every 1Password window to the passwords workspace. We
      # cannot distinguish the main vault from transient overlays
      # (SSH-agent auth, etc.) at niri's open-time rule evaluation:
      # they share the app-id, and 1Password sets titles only after
      # the window is already mapped — too late for `open-on-workspace`
      # decisions. Trade-off: the SSH-auth prompt also pops on the
      # passwords workspace; you have to Mod-jump back. Acceptable cost
      # for getting the main window routed reliably.
      {
        match.app-id = "^1password$";
        openOnWorkspace = "passwords";
      }
    ];
  };

  # Home-manager half: op-cache helper + routing SSH through the GUI's
  # agent. In homeManager.base (not desktop) because git signing and
  # direnv depend on it everywhere the user exists.
  flake.modules.homeManager.base = { pkgs, ... }:
    let
      # Prebuilt op-cache release from github.com/simlans/direnv-libs.
      # Caches `op read` lookups locally so direnv reloads don't hit the
      # 1Password API on every cd. The system-wide `op` (1Password CLI)
      # comes from the NixOS half above.
      op-cache = pkgs.stdenv.mkDerivation rec {
        pname = "op-cache";
        version = "2.0.0";

        src = pkgs.fetchurl {
          url = "https://github.com/simlans/direnv-libs/releases/download/v${version}/op-cache-x86_64-unknown-linux-gnu.tar.gz";
          hash = "sha256-zGV1QdTi6w9frne91xiLyZZg8YhqdEFc+y/JlhK1jhQ=";
        };

        sourceRoot = "op-cache-x86_64-unknown-linux-gnu";
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        # The Rust binary dynamically links against libgcc_s.so.1.
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];
        dontBuild = true;

        installPhase = ''
          runHook preInstall
          install -Dm755 op-cache $out/bin/op-cache
          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Caching wrapper around 1Password CLI for direnv";
          homepage = "https://github.com/simlans/direnv-libs";
          platforms = [ "x86_64-linux" ];
        };
      };
    in
    {
      home.packages = [ op-cache ];

      # Route SSH (and therefore git via gpg.format=ssh) through the 1Password
      # GUI's built-in SSH agent. Activate the agent once in the GUI:
      # Settings → Developer → "Use the SSH agent".
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        # 26.05 deprecated `matchBlocks` (camelCase aliases) in favour of
        # `settings`, which takes upstream OpenSSH directive names verbatim.
        settings."*" = {
          IdentityAgent = "~/.1password/agent.sock";
          ForwardAgent = false;
          AddKeysToAgent = "no";
          Compression = false;
          ServerAliveInterval = 0;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "no";
          ControlPath = "~/.ssh/master-%r@%n:%p";
          ControlPersist = "no";
        };
      };
    };
}
