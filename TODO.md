# TODO

- [ ] Revert `flake.nix` nixpkgs input from `release-25.11` back to `nixos-25.11` once the channel advances past the Nix daemon LPE fix (GHSA-vh5x-56v6-4368, PR #516633, merged 2026-05-04). Check via `git ls-remote https://github.com/NixOS/nixpkgs nixos-25.11` or status.nixos.org.
- [x] Replace Discord with Vesktop (open-source client) — screen sharing doesn't work in Discord
- [ ] Switch font away from the current one to something with a finer style
- [ ] Adjust tmux colors to match Catppuccin
- [ ] Rename Tailscale host — "battlestation" is already taken by the Windows machine
- [ ] Install OpenCloud
- [ ] Install a suitable file manager
- [x] Readd Mod+D besides Mod+Space to open app launcher
- [x] Use Noctalia Login screen alternative
- [x] Add own workspace "gaming" for Steam
- [x] VSCode Terminal shows square icon instead of a NixOS Flake symbol
- [x] Wire up the Elgato Cam Link 4K (USB HDMI capture) so it shows up as a v4l2 source for video calls / OBS
- [ ] Fix `applyLocalFullName` activation script in `modules/system/users.nix:55-58`: it calls `${pkgs.coreutils}/bin/getent`, but `getent` ships in `pkgs.glibc.bin` (coreutils never had it). Activation prints `No such file or directory` on every rebuild; the script reaches its goal accidentally because the failed `getent` returns empty and the subsequent `usermod -c` still runs. Replace with `${pkgs.glibc.bin}/bin/getent` (or drop getent and read GECOS another way).