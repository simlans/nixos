{ inputs, ... }:
{
  flake.modules.nixos.base = { config, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops.defaultSopsFile = ../../secrets/personal.yaml;

    # `sops.age.sshKeyPaths` defaults to the ed25519 entries in
    # `services.openssh.hostKeys`, which `modules/system/openssh.nix`
    # already populates — no override needed.

    sops.secrets."git/author_name".owner = config.my.primaryUser;
    sops.secrets."git/author_email".owner = config.my.primaryUser;
    sops.secrets."git/github_user".owner = config.my.primaryUser;

    # Cortecs.AI API key for the OpenAI-compatible provider that the Pi
    # coding agent reads via `apiKey: "!cat …"` in ~/.pi/agent/models.json.
    # See modules/development/pi-coding-agent.nix.
    sops.secrets."pi/cortecs_api_key".owner = config.my.primaryUser;
  };
}
