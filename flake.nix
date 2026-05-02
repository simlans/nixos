{
  description = "NixOS configuration for the battlestation";

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
  };

  outputs = inputs@{ self, nixpkgs, home-manager, disko, lanzaboote, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
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
    };
}
