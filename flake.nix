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

    # Flake outputs are produced by evaluating Nixpkgs-style modules instead
    # of one hand-written attrset — definitions of the same option merge
    # across files, which is what the dendritic layout under `modules/`
    # relies on.
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Auto-imports every .nix file under a directory (ignoring `_`-prefixed
    # paths) so module files never have to be listed by hand.
    import-tree.url = "github:vic/import-tree";

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

    # Encrypted-at-rest secrets. age-encrypted YAML in `secrets/`, decrypted
    # at activation time into `/run/secrets/...` using the system's SSH host
    # key. sops-nix doesn't maintain release-* branches; master targets
    # current-stable nixpkgs and `flake.lock` pins a specific commit.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, disko, lanzaboote, git-hooks, noctalia, nixos-hardware, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ (inputs.import-tree ./modules) ];
      flake = let
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
        # `nix run .#sops-onboard-host -- <ssh-target> <name>` — bootstrap
        # a new machine into sops in one shot. SSHs to <ssh-target>, reads
        # its ed25519 SSH host pubkey, converts it to an age recipient,
        # inserts it into `.sops.yaml` (right before the existing
        # `&user_*` anchor + `*user_*` reference), and runs
        # `sops updatekeys` so `secrets/personal.yaml` is re-encrypted
        # for the new host. Idempotent: re-running with an already-
        # onboarded `<name>` is a no-op. The local user needs:
        #   - SSH access to the target (the 1P SSH agent serves the
        #     authorized key declared in `modules/system/openssh.nix`),
        #   - `SOPS_AGE_KEY` in the environment so this script's
        #     `sops updatekeys` call can decrypt before re-encrypting.
        #     The repo's `.envrc` exports it from 1Password
        #     (`op://Private/nixos-sops-keyfile`), so running `nix run`
        #     from inside the direnv'd repo shell is sufficient —
        #     no on-disk `~/.config/sops/age/keys.txt` required.
        # Run from inside the repo so direnv has loaded the env.
        # Prints the remaining git/rebuild commands to stdout when done.
        sops-onboard-host = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "sops-onboard-host";
            runtimeInputs = with pkgs; [
              openssh
              ssh-to-age
              sops
              gawk
              gnugrep
              coreutils
              git
            ];
            text = ''
              if [ $# -lt 2 ]; then
                cat >&2 <<'USAGE'
              usage: nix run .#sops-onboard-host -- <ssh-target> <flake-host>

                <ssh-target>  network address for the pubkey fetch. Anything
                              `ssh` accepts — IP, hostname, Tailscale MagicDNS,
                              ~/.ssh/config alias. e.g. lansing@192.168.1.42,
                              lansing@workstation.local, lansing@workstation.
                <flake-host>  logical name. Becomes `&host_<flake-host>` in
                              .sops.yaml and the `#<flake-host>` target of
                              `nixos-rebuild --flake .#<flake-host>`. Must
                              match a `nixosConfigurations.<name>` entry —
                              currently `battlestation` or `workstation`.

              Most-common case (DNS resolves the name): both args identical, e.g.
                nix run .#sops-onboard-host -- lansing@workstation workstation
              USAGE
                exit 1
              fi
              target="$1"
              name="$2"

              repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
                echo "ERROR: not in a git repo (run from inside nixos/)" >&2
                exit 1
              }
              cd "$repo_root"

              [ -f .sops.yaml ] || { echo "ERROR: $repo_root/.sops.yaml not found" >&2; exit 1; }
              [ -f secrets/personal.yaml ] || { echo "ERROR: $repo_root/secrets/personal.yaml not found" >&2; exit 1; }

              if grep -q "&host_$name " .sops.yaml; then
                echo "host_$name already present in .sops.yaml; nothing to do" >&2
                exit 0
              fi

              # The awk insertion uses the user_* anchor/reference as the
              # "before this line" marker — fail loudly if the convention
              # has drifted, instead of silently producing a malformed file.
              grep -q "^  - &user_" .sops.yaml \
                || { echo "ERROR: .sops.yaml has no '&user_*' anchor to insert before" >&2; exit 1; }
              grep -q "^          - \*user_" .sops.yaml \
                || { echo "ERROR: .sops.yaml has no '*user_*' reference to insert before" >&2; exit 1; }

              echo "==> fetching SSH host pubkey from $target" >&2
              pubkey=$(ssh "$target" 'cat /etc/ssh/ssh_host_ed25519_key.pub' | ssh-to-age)
              [ -n "$pubkey" ] || { echo "ERROR: empty age pubkey from $target" >&2; exit 1; }
              echo "    $pubkey" >&2

              echo "==> inserting host_$name into .sops.yaml" >&2
              tmp=$(mktemp)
              awk -v name="$name" -v pubkey="$pubkey" '
                /^  - &user_/ && !did_key { print "  - &host_" name " " pubkey; did_key = 1 }
                /^          - \*user_/ && !did_ref { print "          - *host_" name; did_ref = 1 }
                { print }
              ' .sops.yaml > "$tmp"
              mv "$tmp" .sops.yaml

              echo "==> re-encrypting secrets/personal.yaml" >&2
              sops updatekeys --yes secrets/personal.yaml

              cat <<EOF

              Done. Now (locally):
                git -C $repo_root commit -am "sops: onboard $name"
                git -C $repo_root push

              Then on $name:
                git pull
                sudo nixos-rebuild switch --flake ~/Projects/nixos#$name
              EOF
            '';
          }}/bin/sops-onboard-host";
        };

        # `nix run .#tailscale-up` — bootstrap this node into the tailnet.
        # Default is browser-based auth: `tailscale up` prints a one-time
        # login URL on first run. Optional: pipe an auth key on stdin
        # (`echo "$key" | nix run .#tailscale-up`) to skip the browser.
        # Calls `sudo tailscale up` with the standard --accept-dns
        # --accept-routes flags. Single-shot: tailscale persists the node
        # identity under /var/lib/tailscale.
        tailscale-up = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "tailscale-up";
            runtimeInputs = [ pkgs.tailscale ];
            text = ''
              if [ ! -t 0 ]; then
                key="$(cat)"
                exec sudo tailscale up \
                  --auth-key="$key" \
                  --accept-dns \
                  --accept-routes
              fi
              exec sudo tailscale up \
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
    };
}
