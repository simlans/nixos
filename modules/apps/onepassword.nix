{ ... }:
{
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "lansing" ];
  };

  # Route SSH through 1Password's agent. pam_gnome_keyring.so otherwise
  # exports SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh at session start, which
  # squats on every shell and breaks `git commit` (SSH-signed) since
  # gnome-keyring's agent has no keys. The 1P agent socket is created by
  # the GUI when "Use SSH agent" is enabled in 1Password → Developer.
  environment.sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
}
