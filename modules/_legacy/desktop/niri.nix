{ config, lib, pkgs, inputs, ... }:
let
  # niri on the 25.11 channel ships 25.11; nixos-unstable ships 26.04, which
  # adds the blur effects that Noctalia recommends for its "modern look" niri
  # setup. Pull niri from unstable — same pattern as claude-code / vscode.
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  imports = [ ./keyboard-layout.nix ];

  options.lansing.desktop.niri = {
    workspaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "passwords" "communication" "main" "gaming" ];
      description = ''
        Named niri workspaces in declaration order. They are persistent —
        always present, even when empty. Niri assigns them stable
        indices 1..N matching this order, so Mod+1 focuses the first
        entry, Mod+2 the second, etc. Rendered into niri.kdl at the
        @WORKSPACES@ marker.

        Niri focuses the first declared workspace at session start.
        The startup-focus override (a spawn-at-startup running
        `niri msg action focus-workspace main` in niri.kdl) jumps the
        session to `main` so login doesn't land on the password
        surface.

        Note: niri does not auto-create named workspaces from
        `open-on-workspace` rules. Every workspace referenced in
        `appWindowRules.openOnWorkspace` must be declared here, or the
        rule is silently ignored.
      '';
    };

    workspaceOutputs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Map of workspace-name → output-name to pin a named workspace to
        a specific output. Workspaces not listed here stay unbound and
        spawn on whatever output is currently focused. Set per host;
        e.g. on the workstation `{ communication = "eDP-1"; }` keeps
        the comms workspace on the laptop panel even when an external
        monitor is plugged in.
      '';
    };

    appWindowRules = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          match = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            description = ''
              Niri `match` properties (e.g. { app-id = "^Slack$"; }).
              Values are KDL string literals — typically regex.
            '';
          };
          openOnWorkspace = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Target workspace name. Must match an entry in
              `workspaces` — niri silently ignores rules pointing at
              undeclared workspaces.
            '';
          };
          openFloating = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
          };
          defaultColumnWidthProportion = lib.mkOption {
            type = lib.types.nullOr lib.types.float;
            default = null;
            description = ''
              When set, the matched window opens at this proportion of
              the output width (e.g. 0.15 for a slim sidebar-like
              column). Rendered as niri's
              `default-column-width { proportion X; }`. Only applies
              at window creation — resizing the window afterwards is
              still allowed.
            '';
          };
        };
      });
      default = [ ];
      description = ''
        Per-app niri window rules contributed by individual app modules
        (modules/apps/*.nix). Aggregated and rendered into niri.kdl at
        the @APP_WINDOW_RULES@ marker.
      '';
    };
  };

  config = {
    assertions =
      (map (rule: {
        assertion = rule.openOnWorkspace == null
          || builtins.elem rule.openOnWorkspace config.lansing.desktop.niri.workspaces;
        message =
          "lansing.desktop.niri.appWindowRules entry for app-id "
          + "'${rule.match.app-id or "?"}' targets workspace "
          + "'${toString rule.openOnWorkspace}', which is not in "
          + "lansing.desktop.niri.workspaces "
          + "(${lib.concatStringsSep ", " config.lansing.desktop.niri.workspaces}).";
      }) config.lansing.desktop.niri.appWindowRules)
      ++ (lib.mapAttrsToList (ws: _output: {
        assertion = builtins.elem ws config.lansing.desktop.niri.workspaces;
        message =
          "lansing.desktop.niri.workspaceOutputs binds workspace "
          + "'${ws}' which is not declared in "
          + "lansing.desktop.niri.workspaces "
          + "(${lib.concatStringsSep ", " config.lansing.desktop.niri.workspaces}).";
      }) config.lansing.desktop.niri.workspaceOutputs);

    programs.niri = {
      enable = true;
      package = unstable.niri;
    };

    # Niri is pure Wayland; X11 apps (Steam, etc.) need rootless Xwayland via
    # xwayland-satellite. There is no NixOS module for it in 25.11, so wire it
    # up as a systemd user service tied to graphical-session.target.
    environment.systemPackages = [ pkgs.xwayland-satellite ];
    # DISPLAY for X11 clients lives in niri's `environment { … }` block in
    # niri.kdl, NOT in environment.sessionVariables. wlroots' backend
    # autodetection (used by cage, which hosts ReGreet under greetd) treats
    # DISPLAY in the env as "use the X11 backend" and tries to xcb_connect
    # to that display at boot — there is no X server, so cage exits with
    # "Failed to open xcb connection" and the greeter never appears. Scoping
    # DISPLAY to niri-spawned children keeps greetd/cage clean.
    # Tells nixpkgs Electron/Chromium wrappers (spotify, vscode, …) to launch
    # natively on Wayland. Without this they fall back to XWayland and ignore
    # niri's prefer-no-csd, leaving CSD title bars in place.
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

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

    # ReGreet is a GTK4 graphical greeter for greetd. Enabling the NixOS
    # module flips on `services.greetd` for us and sets
    # `default_session.command` (via mkDefault) to
    # `dbus-run-session cage -s -- regreet`. niri's wayland-session
    # desktop file (installed by `programs.niri`) shows up in the
    # session dropdown automatically — no hard-coded `--cmd niri-session`
    # like the old tuigreet config.
    programs.regreet = {
      enable = true;
      # Match the rest of the system (modules/desktop/fonts.nix). Default
      # is Cantarell 16, tuned for a sans face — drop a couple of points
      # for the mono.
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 14;
      };
      settings = {
        GTK = {
          application_prefer_dark_theme = true;
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
  };
}
