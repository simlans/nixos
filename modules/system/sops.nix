{ inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops.defaultSopsFile = ../../secrets/personal.yaml;

  # `sops.age.sshKeyPaths` defaults to the ed25519 entries in
  # `services.openssh.hostKeys`, which `modules/system/openssh.nix`
  # already populates — no override needed.

  sops.secrets."git/author_name".owner = "lansing";
  sops.secrets."git/author_email".owner = "lansing";
  sops.secrets."git/github_user".owner = "lansing";
}
