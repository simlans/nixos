# TODO

## NixOS 26.05 upgrade

`flake.nix` points at `nixos-26.05` / `home-manager release-26.05`. battlestation is switched and live as of 2026-06-11 (generation `26.05.20260608.bd0ff2d (Yarara)`). workstation has not been switched yet. `system.stateVersion` and `home.stateVersion` deliberately stay on `"25.11"` (they pin install-time defaults, not the channel).

- [ ] Switch the workstation laptop to 26.05 (`sudo nixos-rebuild switch --flake .#workstation`); it shares the same flake so the same blockers / cleanups apply.
- [x] **Noctalia v4 → v5 migration** done. `flake.nix` now pins an explicit v5 (main) commit; `modules/desktop/noctalia.nix` ported to the v5 schema (`programs.noctalia`, `theme`/`location`/`hooks.started`, `bar.main.{start,center,end}`, per-widget `[widget.<id>]` tables — note the IDs are `sysmon` and `active_window`, not the dashed forms first guessed). `modules/desktop/niri.kdl` was migrated alongside it: the startup spawn and the launcher/lock/session-menu binds moved from the old `noctalia-shell ipc call …` syntax to the `noctalia msg …` syntax. Clock weekday/month names render in English (kept the `en_US.UTF-8` default locale). Still to verify: the `^noctalia-…` window-rule namespaces in `niri.kdl:422/428` (v5 may have renamed the layer-shell namespaces).
- [ ] **Re-evaluate the "unstable because stable lags" workarounds** once the build is green on 26.05 — several were justified against 25.11 specifically:
  - `modules/development/claude-code.nix` — comment said 25.11 lagged ~30 patches.
  - `modules/desktop/niri.nix` — comment said 25.11 ships 25.11, unstable ships 26.04; 26.05 may now ship a recent-enough niri.
  - `modules/development/vscodium.nix` — manifest lag concern.
  - `modules/gaming/lutris.nix` — 25.11 shipped 0.5.19.
  - `modules/development/pi-coding-agent.nix` — was not packaged in 25.11 at all; check 26.05.
- [ ] **Home-manager neovim defaults flipped in 26.05.** `programs.neovim.withRuby` and `withPython3` now default to `false`; we currently keep the legacy `true` defaults implicitly because `home.stateVersion = "25.11"`. Decide whether to set them explicitly or accept the new defaults the next time `home.stateVersion` is bumped (`modules/users/lansing.nix:22`).
- [ ] **Home-manager option renames surfaced on the 26.05 switch.** Non-blocking deprecations; each will hard-fail in a later release.
  - `programs.neovim.extraLuaConfig` → `programs.neovim.initLua` in `modules/development/neovim.nix`.
  - `programs.vscode.package = pkgs.vscodium` no longer redirects to the fork's paths — Home-Manager warns to use `programs.vscodium` instead. Affects `modules/development/vscodium.nix`.
  - `programs.ssh.matchBlocks` → `programs.ssh.settings` in `modules/apps/onepassword.nix`.

- [x] Replace Discord with Vesktop (open-source client) — screen sharing doesn't work in Discord
- [ ] Switch font away from the current one to something with a finer style
- [ ] Adjust tmux colors to match Catppuccin
- [ ] Rename Tailscale host — "battlestation" is already taken by the Windows machine
- [x] Install OpenCloud
- [ ] Install a suitable file manager
- [x] Readd Mod+D besides Mod+Space to open app launcher
- [x] Use Noctalia Login screen alternative
- [x] Add own workspace "gaming" for Steam
- [x] VSCode Terminal shows square icon instead of a NixOS Flake symbol
- [x] Wire up the Elgato Cam Link 4K (USB HDMI capture) so it shows up as a v4l2 source for video calls / OBS
- [ ] Fix `applyLocalFullName` activation script in `modules/system/users.nix:55-58`: it calls `${pkgs.coreutils}/bin/getent`, but `getent` ships in `pkgs.glibc.bin` (coreutils never had it). Activation prints `No such file or directory` on every rebuild; the script reaches its goal accidentally because the failed `getent` returns empty and the subsequent `usermod -c` still runs. Replace with `${pkgs.glibc.bin}/bin/getent` (or drop getent and read GECOS another way).