# TODO

## NixOS 26.05 upgrade

`flake.nix` points at `nixos-26.05` / `home-manager release-26.05`. battlestation is switched and live as of 2026-06-11 (generation `26.05.20260608.bd0ff2d (Yarara)`). workstation has not been switched yet. `system.stateVersion` and `home.stateVersion` deliberately stay on `"25.11"` (they pin install-time defaults, not the channel).

- [ ] Switch the workstation laptop to 26.05 (`sudo nixos-rebuild switch --flake .#workstation`); it shares the same flake so the same blockers / cleanups apply.
- [x] **Noctalia v4 → v5 migration** done. `flake.nix` now pins an explicit v5 (main) commit; `modules/desktop/noctalia.nix` ported to the v5 schema (`programs.noctalia`, `theme`/`location`/`hooks.started`, `bar.main.{start,center,end}`, per-widget `[widget.<id>]` tables — note the IDs are `sysmon` and `active_window`, not the dashed forms first guessed). `modules/desktop/niri.kdl` was migrated alongside it: the startup spawn and the launcher/lock/session-menu binds moved from the old `noctalia-shell ipc call …` syntax to the `noctalia msg …` syntax. Clock weekday/month names render in English (kept the `en_US.UTF-8` default locale). Layer-shell namespaces verified against the v5 source (`7421f80`): v5 dropped per-instance suffixes and uses flat names, so the old `^noctalia-(background|launcher-overlay|dock)-.*$` rule matched nothing — updated to `^noctalia-(backdrop|panel|attached-panel|dock|overview-launcher)$` (`background`→`backdrop`, `launcher-overlay`→`panel`/`overview-launcher`). The wallpaper rule still matches (`noctalia-wallpaper`, confirmed live via `niri msg layers`).
- [ ] **Re-evaluate the "unstable because stable lags" workarounds** once the build is green on 26.05 — several were justified against 25.11 specifically:
  - `modules/development/claude-code.nix` — comment said 25.11 lagged ~30 patches.
  - `modules/desktop/niri.nix` — comment said 25.11 ships 25.11, unstable ships 26.04; 26.05 may now ship a recent-enough niri.
  - `modules/development/vscodium.nix` — manifest lag concern.
  - `modules/gaming/lutris.nix` — 25.11 shipped 0.5.19.
  - `modules/development/pi-coding-agent.nix` — was not packaged in 25.11 at all; check 26.05.
- [x] **Home-manager neovim defaults flipped in 26.05.** Adopted the new `false` defaults explicitly: `programs.neovim.withRuby = false; withPython3 = false;` in `modules/development/neovim.nix` (LazyVim is lua-only).
- [x] **Home-manager option renames surfaced on the 26.05 switch.** All migrated and verified with a clean `nixos-rebuild build` (no eval warnings):
  - `programs.neovim.extraLuaConfig` → `programs.neovim.initLua` in `modules/development/neovim.nix`.
  - `programs.vscode` → `programs.vscodium` (its own module) in `modules/development/vscodium.nix`; the manual `.vscode-oss/argv.json` `home.file` was replaced by the module's `argvSettings` (it writes to `.vscode-oss/` natively).
  - `programs.ssh.matchBlocks."*"` → `programs.ssh.settings."*"` in `modules/apps/onepassword.nix`, rewritten with upstream OpenSSH directive names (`IdentityAgent`, `ForwardAgent`, …) instead of the camelCase aliases.

- [x] Replace Discord with Vesktop (open-source client) — screen sharing doesn't work in Discord
- [x] Switch font away from the current one to something with a finer style
- [x] Adjust tmux colors to match Catppuccin — remapped the 17 `tmux_conf_theme_colour_*` variables in `modules/shell/tmux/tmux.conf.local` (oh-my-tmux default theme) to Catppuccin Mocha pastels, keeping the existing layout (yellow session / pink arrow / blue window / red user / grey host). Dark Crust text on the lighter pastel accents for legibility; hostname moved from white to a Surface2 grey with Text-coloured foreground.
- [ ] Rename Tailscale host — "battlestation" is already taken by the Windows machine
- [x] Install OpenCloud
- [ ] Install a suitable file manager
- [x] Readd Mod+D besides Mod+Space to open app launcher
- [x] Use Noctalia Login screen alternative
- [x] Add own workspace "gaming" for Steam
- [x] VSCode Terminal shows square icon instead of a NixOS Flake symbol
- [x] Wire up the Elgato Cam Link 4K (USB HDMI capture) so it shows up as a v4l2 source for video calls / OBS
- [x] Fixed `applyLocalFullName` activation script in `modules/system/users.nix`: it called `${pkgs.coreutils}/bin/getent`, but `getent` is not in coreutils (it's glibc). Replaced with `${pkgs.getent}/bin/getent` (the dedicated glibc-getent package — cleaner than `${pkgs.glibc.bin}/bin/getent`). Verified the built activate script now references `getent-glibc`. Done in `d1a4d3d`.
