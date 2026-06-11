{
  flake.modules.homeManager.base = {
    # Blazing-fast TUI file manager (https://github.com/sxyazi/yazi).
    # `enableZshIntegration` ships the `yy` shell wrapper: it launches yazi,
    # and on quit cd's the parent shell to the directory yazi left off in
    # (plain `yazi` can't change the shell's cwd; the wrapper reads its
    # `--cwd-file` and `builtin cd`s there). Note the name is `yy`, not `y`.
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
