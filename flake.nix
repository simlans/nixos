{
  description = "NixOS configuration for simlans's machines (battlestation desktop, workstation laptop)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

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

      # `nix run .#tailscale-up` — bootstrap this node into the tailnet.
      # Reads the auth key either from a TTY prompt or from stdin, so both
      # interactive use and `op read 'op://nixos/tailscale-nixos-authkey/credential'
      #   | nix run .#tailscale-up` work. Calls `sudo tailscale up` with
      # the standard --accept-dns --accept-routes flags. Single-shot:
      # tailscale persists the node identity under /var/lib/tailscale.
      apps.${system}.tailscale-up = {
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
