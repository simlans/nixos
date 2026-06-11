# Reference: https://docs.noctalia.dev/v5/getting-started/nixos/
{ inputs, ... }:
{
  flake.modules.homeManager.desktop = { config, ... }: {
    imports = [ inputs.noctalia.homeModules.default ];

    programs.noctalia = {
      enable = true;
      # Home-Manager still accepts a Nix attrset and serialises it to TOML.
      settings = {
        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Catppuccin";
        };
        location = {
          address = "Düsseldorf, Germany";
          auto_locate = false;
        };
        wallpaper = {
          enabled = true;
          directory = "${config.home.homeDirectory}/Pictures/wallpapers";
        };
        hooks.started = "noctalia msg wallpaper-random";
        # v5 dropped the global shadow toggle; alpha = 0 keeps shadows off.
        shell.shadow.alpha = 0;

        bar.main = {
          start = [ "launcher" "clock" "sysmon" "active_window" ];
          center = [ "workspaces" ];
          end = [ "media" "tray" "notifications" "battery" "volume" "brightness" "control-center" ];
        };

        # Per-widget settings live in their own tables in v5 (no longer inline
        # on each bar entry).
        widget = {
          clock = {
            # Python strftime (renders in the process locale = en_US, so the
            # weekday/month names come out English):
            #   %a = weekday abbreviated, %-d = day without leading zero,
            #   %B = month spelled out, %H:%M:%S = 24h time.
            format = "{:%a. %-d. %B %H:%M:%S}";
            tooltip_format = "{:%Y-%m-%d %H:%M:%S}";
          };
          active_window.max_length = 500;
          media.max_length = 500;
          workspaces.display = "name";
        };
      };
    };
  };
}
