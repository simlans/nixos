{
  flake.modules.homeManager.base = { pkgs, ... }: {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        size = 100000;
        save = 100000;
        extended = true;
        ignoreAllDups = true;
        ignoreSpace = true;
        saveNoDups = true;
        share = true;
      };

      shellAliases = {
        k = "kubectl";
        kgp = "kubectl get pods";
        kgs = "kubectl get svc";
        kga = "kubectl get all";
        kaf = "kubectl apply -f";
        ll = "ls -la";
        ".." = "cd ..";
        "..." = "cd ../..";
      };

      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "kubectl"
          "z"
          "sudo"
          "colored-man-pages"
        ];
      };

      # Powerlevel10k theme + the wizard-generated config in p10k/p10k.zsh.
      # Plugins are sourced after oh-my-zsh, so p10k overrides whatever default
      # theme OMZ loaded. Order matters: theme first, then config.
      plugins = [
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        {
          name = "powerlevel10k-config";
          src = ./p10k;
          file = "p10k.zsh";
        }
      ];

      # Bootstrap intentionally omits the SSH-agent setup (handled by the
      # 1Password GUI agent) and runtime `git config --global` mutations
      # (declared in git.nix). 1Password CLI auth is delegated to the desktop
      # app via "Integrate with 1Password CLI" — no per-shell `op signin`.
      initContent = ''
        # `rebuild [path]` — bump every flake input, then switch.
        # Targets the current directory by default; pass a path to build a
        # different checkout (e.g. `rebuild ~/Projects/nixos`). A plain
        # `nixos-rebuild` only builds what flake.lock pins, so floating
        # packages (claude-code from nixpkgs-unstable, see
        # development/claude-code.nix) never advance without a lock bump first.
        # `&&` is fail-fast: a failed update aborts before the switch. No host
        # attr needed — nixos-rebuild defaults the flake attribute to the
        # current hostname (.#battlestation, .#workstation, …). Run
        # `sudo nixos-rebuild switch` directly to build WITHOUT updating.
        rebuild() {
          local flake="''${1:-.}"
          nix flake update --flake "$flake" && sudo nixos-rebuild switch --flake "$flake"
        }

        # Fall back to xterm-256color for unknown terminfo entries (e.g. xterm-ghostty)
        if ! infocmp "$TERM" &>/dev/null 2>&1; then
          export TERM=xterm-256color
        fi

        # PATH for user-installed tooling that lives outside the Nix store
        export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
        export COLORTERM=truecolor

        # Start a fresh tmux session per Alacritty window so windows stay
        # isolated — no shared window list across terminals.
        # $ALACRITTY_WINDOW_ID (exported by Alacritty since 0.13) gives each
        # session a stable, distinct name visible in `tmux ls`.
        if command -v tmux >/dev/null && [ -z "$TMUX" ] && [ -n "$ALACRITTY_WINDOW_ID" ]; then
          tmux new-session -s "alacritty-$ALACRITTY_WINDOW_ID"
        fi
      '';
    };
  };
}
