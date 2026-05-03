# Reference: https://docs.noctalia.dev/v4/getting-started/nixos/
{ config, inputs, ... }:
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia-shell = {
    enable = true;
    settings = {
      colorSchemes = {
        predefinedScheme = "Catppuccin";
        darkMode = true;
        useWallpaperColors = false;
        schedulingMode = "auto";
      };
      location = {
        name = "Düsseldorf, Germany";
        autoLocate = false;
      };
      wallpaper = {
        enabled = true;
        directory = "${config.home.homeDirectory}/Pictures/wallpapers";
      };
      hooks = {
        enabled = true;
        startup = ''noctalia-shell ipc call wallpaper random ""'';
      };
      general.enableShadows = false;
      bar.widgets = {
        left = [
          { id = "Launcher"; }
          {
            id = "Clock";
            # Qt date/time format (case-sensitive): yyyy = 4-digit year,
            # MM = 2-digit month, dd = 2-digit day, HH = 24h hour,
            # mm = minute, ss = second.
            formatHorizontal = "yyyy-MM-dd HH:mm:ss";
            tooltipFormat = "yyyy-MM-dd HH:mm:ss";
          }
          { id = "SystemMonitor"; }
          { id = "ActiveWindow"; maxWidth = 500; }
        ];
        center = [
          { id = "Workspace"; }
        ];
        right = [
          { id = "MediaMini"; maxWidth = 500; }
          { id = "Tray"; }
          { id = "NotificationHistory"; }
          { id = "Battery"; }
          { id = "Volume"; }
          { id = "Brightness"; }
          { id = "ControlCenter"; }
        ];
      };
    };
  };
}
