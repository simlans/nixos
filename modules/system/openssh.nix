{
  flake.modules.nixos.base = {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    # Per-user authorized keys live with the user aspect
    # (modules/users/<name>.nix), not here — this file is the daemon only.
  };
}
