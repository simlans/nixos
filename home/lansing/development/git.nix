{ pkgs, lib, osConfig, ... }:
let
  email = "55317770+simlans@users.noreply.github.com";

  # Public ed25519 SSH key used for signing git commits and tags.
  # Public keys are designed to be shared — verifying signatures is the only
  # operation they enable, and GitHub already publishes this key under
  # https://api.github.com/users/simlans/ssh_signing_keys. The matching
  # private key lives only in 1Password and is exposed at runtime via the
  # GUI's ~/.1password/agent.sock (see home/lansing/onepassword.nix).
  signingPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ8KVxjQP4VDhBn3ux8LqstUDjXYHDDVbZgrfVouX4ty";

  # Source for ~/.envrc. Installed as a real file (not a /nix/store symlink)
  # because direnv touches the mtime on every load — a read-only symlink
  # target would error out with `chtimes: read-only file system` and abort.
  # The `[ -r ... ]` guard makes this graceful on first boot before sops has
  # been bootstrapped on the host: shells start cleanly, just without the
  # GIT_AUTHOR_*/GITHUB_USER env-vars, until /run/secrets/git/* materialises.
  privateEnvrc = pkgs.writeText "private-identity-envrc" ''
    if [ -r "${osConfig.sops.secrets."git/author_name".path}" ]; then
      GIT_AUTHOR_NAME=$(cat "${osConfig.sops.secrets."git/author_name".path}")
      GIT_AUTHOR_EMAIL=$(cat "${osConfig.sops.secrets."git/author_email".path}")
      GITHUB_USER=$(cat "${osConfig.sops.secrets."git/github_user".path}")
      export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GITHUB_USER
      export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
      export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
    fi
  '';
in
{
  home.packages = [ pkgs.gh ];

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;

    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";

      credential.helper = "${pkgs.gh}/bin/gh auth git-credential";
    };
  };

  xdg.configFile."git/allowed_signers".text =
    "${email} ${signingPublicKey}\n";

  # Signing config lives at ~/.gitconfig (overrides ~/.config/git/config per
  # git-config(1) precedence). Identity (user.name/email) is intentionally
  # absent here — it flows in via ~/.envrc env vars from sops-decrypted
  # files at /run/secrets/git/* so the private email never lands in
  # /nix/store.
  home.file.".gitconfig".text = ''
    [user]
    	signingkey = ${signingPublicKey}

    [gpg]
    	format = ssh

    [gpg "ssh"]
    	program = ${pkgs._1password-gui}/share/1password/op-ssh-sign
    	allowedSignersFile = ~/.config/git/allowed_signers

    [commit]
    	gpgsign = true

    [tag]
    	gpgsign = true
  '';

  # Parent .envrc auto-loaded by direnv for any subdirectory of $HOME.
  # Per-repo .envrc files override these. Installed as a real file via
  # activation (see `privateEnvrc` rationale above).
  home.activation.installPrivateEnvrc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD rm -f $HOME/.envrc
    $DRY_RUN_CMD install -m644 ${privateEnvrc} $HOME/.envrc
  '';
}
