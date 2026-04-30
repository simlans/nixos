{ pkgs, ... }:
{
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
    # (declared in git.nix).
    initContent = ''
      # Fall back to xterm-256color for unknown terminfo entries (e.g. xterm-ghostty)
      if ! infocmp "$TERM" &>/dev/null 2>&1; then
        export TERM=xterm-256color
      fi

      # PATH for user-installed tooling that lives outside the Nix store
      export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
      export COLORTERM=truecolor

      # 1Password CLI signin (idempotent; only if not already signed in)
      if command -v op >/dev/null && ! op whoami --account my.1password.eu &>/dev/null; then
        eval "$(op signin --account my.1password.eu)"
        if [ -n "$TMUX" ]; then
          for var in $(env | grep '^OP_SESSION_'); do
            tmux setenv "''${var%%=*}" "''${var#*=}"
          done
        fi
      fi

      # Auto-attach to a tmux session named "main" when launched from Alacritty.
      # $ALACRITTY_WINDOW_ID is exported by Alacritty since 0.13. Runs after
      # the 1P signin so the OP_SESSION_* vars propagate into the new tmux
      # session via env inheritance.
      if command -v tmux >/dev/null && [ -z "$TMUX" ] && [ -n "$ALACRITTY_WINDOW_ID" ]; then
        tmux attach-session -t main 2>/dev/null || tmux new-session -s main
      fi
    '';
  };
}
