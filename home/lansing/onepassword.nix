{ pkgs, ... }:
let
  # Prebuilt op-cache release from github.com/simlans/direnv-libs.
  # Caches `op read` lookups locally so direnv reloads don't hit the
  # 1Password API on every cd. The system-wide `op` (1Password CLI)
  # comes from modules/apps/onepassword.nix.
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
    matchBlocks."*" = {
      identityAgent = "~/.1password/agent.sock";
      forwardAgent = false;
      addKeysToAgent = "no";
      compression = false;
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "~/.ssh/known_hosts";
      controlMaster = "no";
      controlPath = "~/.ssh/master-%r@%n:%p";
      controlPersist = "no";
    };
  };
}
