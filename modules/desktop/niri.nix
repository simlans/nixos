{ config, pkgs, ... }:
{
  imports = [ ./keyboard-layout.nix ];

  programs.niri.enable = true;

  # Wire PAM for swaylock so it can actually authenticate. The package and
  # styling live in home-manager (home/lansing/desktop/swaylock.nix).
  security.pam.services.swaylock = {};

  # Niri is pure Wayland; X11 apps (Steam, etc.) need rootless Xwayland via
  # xwayland-satellite. There is no NixOS module for it in 25.11, so wire it
  # up as a systemd user service tied to graphical-session.target.
  environment.systemPackages = [ pkgs.xwayland-satellite ];
  environment.sessionVariables.DISPLAY = ":0";

  systemd.user.services.xwayland-satellite = {
    description = "Xwayland outside your Wayland";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    requisite = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite :0";
      StandardOutput = "journal";
    };
  };

  services.xserver.xkb = {
    layout = if config.lansing.desktop.keyboardLayout == "iso" then "de" else "us";
    variant = "";
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
        user = "greeter";
      };
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
  };
}
