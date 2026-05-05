{
  description = "NixOS configuration for simlans's machines (battlestation desktop, workstation laptop)";

  inputs = {
    # Temporarily on release-25.11 instead of the Hydra-tested nixos-25.11
    # channel to pull in the GHSA-vh5x-56v6-4368 / GHSA-gr92-w2r5-qw5p Nix
    # daemon LPE fix (PR #516633) before the channel advances. Revert to
    # nixos-25.11 once status.nixos.org shows the patch in the channel.
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

    # Bleeding-edge channel used only for fast-moving packages where the
    # 25.11 release lags too far behind upstream (currently: claude-code).
    # Pull from this sparingly and explicitly per package.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Canned hardware modules — used by `workstation` for the
    # Framework 13 Pro / Intel Core Ultra series 3 (Panther Lake) defaults
    # (fwupd, fingerprint, kmod tweaks). nixos-hardware does not take
    # nixpkgs as an input, so no `inputs.nixpkgs.follows` here.
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Marketplace mirror for VSCode extensions — gives access to every
    # extension on the Visual Studio Marketplace and Open VSX, not just
    # the ~200 curated ones in nixpkgs `vscode-extensions`.
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pre-commit framework: provides the devShell `shellHook` that installs
    # `.git/hooks/pre-commit`. Runs `gitleaks` on staged content so secrets
    # can't land in the public history by accident.
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Quickshell-based Wayland shell that replaces waybar. Upstream requires
    # nixpkgs unstable for the Quickshell version it depends on, so we point
    # the input at our unstable channel rather than the 25.11 stable one.
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, disko, lanzaboote, git-hooks, noctalia, nixos-hardware, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pre-commit-check = git-hooks.lib.${system}.run {
        src = ./.;
        hooks.gitleaks = {
          enable = true;
          name = "gitleaks";
          description = "Scan staged content for secrets";
          entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --redact --verbose";
          pass_filenames = false;
        };
      };
    in
    {
      nixosConfigurations.battlestation = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self inputs; };
        modules = [
          disko.nixosModules.disko
          ./disko/battlestation.nix
          lanzaboote.nixosModules.lanzaboote
          ./hosts/battlestation
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.lansing = import ./home/lansing;
          }
        ];
      };

      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self inputs; };
        modules = [
          disko.nixosModules.disko
          ./disko/workstation.nix
          lanzaboote.nixosModules.lanzaboote
          ./hosts/workstation
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.lansing = import ./home/lansing;
          }
        ];
      };

      apps.${system} = {
        # `nix run .#tailscale-up` — bootstrap this node into the tailnet.
        # Reads the auth key either from a TTY prompt or from stdin, so both
        # interactive use and `op read 'op://nixos/tailscale-nixos-authkey/credential'
        #   | nix run .#tailscale-up` work. Calls `sudo tailscale up` with
        # the standard --accept-dns --accept-routes flags. Single-shot:
        # tailscale persists the node identity under /var/lib/tailscale.
        tailscale-up = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "tailscale-up";
            runtimeInputs = [ pkgs.tailscale ];
            text = ''
              if [ ! -t 0 ]; then
                key="$(cat)"
              else
                IFS= read -srp 'Tailscale auth key: ' key
                printf '\n' >&2
              fi
              if [ -z "$key" ]; then
                echo 'no auth key given, aborting' >&2
                exit 1
              fi
              exec sudo tailscale up \
                --auth-key="$key" \
                --accept-dns \
                --accept-routes
            '';
          }}/bin/tailscale-up";
        };

        # `nix run .#init-account` — install-time bootstrap for the
        # `lansing` account: sets the login password via
        # `nixos-enter -c 'passwd lansing'` and seeds the GECOS source
        # file at `<root>/etc/nixos/local/full-name`. Optional positional
        # argument is the mount point of the freshly-installed system
        # (default `/mnt`, i.e. wherever disko-install left the new
        # rootfs). Combines what the README used to spell out as two
        # commands so the whole post-disko-install bootstrap fits in a
        # single `nix run` invocation. To change the realname later on a
        # running system, just edit `/etc/nixos/local/full-name` directly
        # and run `nixos-rebuild switch` — the activation script in
        # `modules/system/users.nix` re-applies it via usermod.
        init-account = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "init-account";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              root="''${1:-/mnt}"

              if [ ! -d "$root/etc" ]; then
                echo "no NixOS root found at $root (expected $root/etc)" >&2
                echo "pass the mount point as the first argument if it is not /mnt" >&2
                exit 1
              fi

              echo "==> Setting login password for user lansing (in $root)" >&2
              sudo nixos-enter --root "$root" -c 'passwd lansing'

              echo "" >&2
              echo "==> Setting GECOS / lock-screen real name" >&2
              IFS= read -rp 'Full name (e.g. "Lansing Surname"): ' name
              if [ -z "$name" ]; then
                echo 'no name given; password is set, but GECOS file was NOT created.' >&2
                echo "Write '$root/etc/nixos/local/full-name' yourself before reboot," >&2
                echo "or edit '/etc/nixos/local/full-name' on the running system later." >&2
                exit 0
              fi
              case "$name" in
                *:*)
                  echo 'name must not contain ":" (would corrupt /etc/passwd)' >&2
                  exit 1
                  ;;
              esac
              target="$root/etc/nixos/local/full-name"
              printf '%s\n' "$name" | sudo install -Dm644 /dev/stdin "$target"
              echo "wrote: $target" >&2
            '';
          }}/bin/init-account";
        };
      };

      # Pre-commit hooks (gitleaks). `nix flake check` runs the suite; the
      # devShell's shellHook installs `.git/hooks/pre-commit` so direnv users
      # get the guard automatically on first entry into the repo.
      checks.${system}.pre-commit = pre-commit-check;

      devShells.${system}.default = pkgs.mkShell {
        inherit (pre-commit-check) shellHook;
        buildInputs = pre-commit-check.enabledPackages;
      };
    };
}
