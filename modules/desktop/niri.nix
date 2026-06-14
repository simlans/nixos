{ inputs, ... }:
let
  # niri on the 25.11 channel ships 25.11; nixos-unstable ships 26.04, which
  # adds the blur effects that Noctalia recommends for its "modern look" niri
  # setup. Pull niri from unstable — same pattern as claude-code / vscode.
  unstableFor = pkgs: import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  flake.modules.nixos.desktop = { config, lib, pkgs, ... }: {
    options.host.desktop.niri = {
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
            || builtins.elem rule.openOnWorkspace config.host.desktop.niri.workspaces;
          message =
            "host.desktop.niri.appWindowRules entry for app-id "
            + "'${rule.match.app-id or "?"}' targets workspace "
            + "'${toString rule.openOnWorkspace}', which is not in "
            + "host.desktop.niri.workspaces "
            + "(${lib.concatStringsSep ", " config.host.desktop.niri.workspaces}).";
        }) config.host.desktop.niri.appWindowRules)
        ++ (lib.mapAttrsToList (ws: _output: {
          assertion = builtins.elem ws config.host.desktop.niri.workspaces;
          message =
            "host.desktop.niri.workspaceOutputs binds workspace "
            + "'${ws}' which is not declared in "
            + "host.desktop.niri.workspaces "
            + "(${lib.concatStringsSep ", " config.host.desktop.niri.workspaces}).";
        }) config.host.desktop.niri.workspaceOutputs);

      programs.niri = {
        enable = true;
        package = (unstableFor pkgs).niri;
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

      # A polkit authentication agent — the per-session UI that renders the
      # password dialog when polkitd needs to authenticate a privileged action.
      # GNOME/KDE start one automatically; niri does not, so without this nothing
      # answers polkit auth requests. Concretely: 1Password's "Unlock using
      # system authentication" registers a polkit action
      # (com.1password.1Password.policy) and asks the session to authenticate it.
      # With no agent running, that request goes unanswered and 1Password
      # silently falls back to prompting for the account (master) password — so
      # every SSH-agent/CLI unlock during git signing or direnv `op read` asks
      # for the master password instead of the Linux login password. Running the
      # agent lets system authentication reach the login-password prompt.
      # hyprpolkitagent ships its own unit, but we declare ours explicitly to
      # match xwayland-satellite above and keep the rationale next to the wiring.
      systemd.user.services.hyprpolkitagent = {
        description = "Polkit authentication agent (enables 1Password system-auth unlock)";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
          Slice = "session.slice";
          Restart = "on-failure";
        };
      };

      services.xserver.xkb = {
        layout = if config.host.desktop.keyboardLayout == "iso" then "de" else "us";
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
  };

  # Home-manager half: renders ~/.config/niri/config.kdl from the niri.kdl
  # template, filling in the markers from the system-side host.desktop.*
  # options (via osConfig — home-manager runs as a NixOS module here).
  flake.modules.homeManager.desktop = { config, lib, osConfig, ... }:
    let
      keys =
        if osConfig.host.desktop.keyboardLayout == "iso" then {
          help      = "Mod+Shift+ssharp";
          consumeL  = "Mod+odiaeresis";
          consumeR  = "Mod+adiaeresis";
          widthDec  = "Mod+minus";
          widthInc  = "Mod+plus";
          heightDec = "Mod+Shift+minus";
          heightInc = "Mod+Shift+plus";
        } else {
          help      = "Mod+Shift+Slash";
          consumeL  = "Mod+BracketLeft";
          consumeR  = "Mod+BracketRight";
          widthDec  = "Mod+Minus";
          widthInc  = "Mod+Equal";
          heightDec = "Mod+Shift+Minus";
          heightInc = "Mod+Shift+Equal";
        };

      niriCfg = osConfig.host.desktop.niri;

      renderWorkspace = name:
        let
          output = niriCfg.workspaceOutputs.${name} or null;
        in
        if output == null then
          "workspace \"${name}\""
        else
          "workspace \"${name}\" {\n    open-on-output \"${output}\"\n}";

      workspacesKdl = lib.concatMapStringsSep "\n" renderWorkspace niriCfg.workspaces;

      renderMatch = m:
        lib.concatStringsSep " "
          (lib.mapAttrsToList (k: v: "${k}=\"${v}\"") m);

      renderRule = rule:
        let
          lines =
            [ "    match ${renderMatch rule.match}" ]
            ++ lib.optional (rule.openOnWorkspace != null)
                "    open-on-workspace \"${rule.openOnWorkspace}\""
            ++ lib.optional (rule.openFloating != null)
                "    open-floating ${lib.boolToString rule.openFloating}"
            ++ lib.optional (rule.defaultColumnWidthProportion != null)
                "    default-column-width { proportion ${toString rule.defaultColumnWidthProportion}; }";
        in
        "window-rule {\n" + lib.concatStringsSep "\n" lines + "\n}";

      appWindowRulesKdl =
        lib.concatMapStringsSep "\n\n" renderRule niriCfg.appWindowRules;
    in
    {
      xdg.configFile."niri/config.kdl".text = builtins.replaceStrings
        [
          "@KEY_HELP@"
          "@KEY_CONSUME_L@"
          "@KEY_CONSUME_R@"
          "@KEY_WIDTH_DEC@"
          "@KEY_WIDTH_INC@"
          "@KEY_HEIGHT_DEC@"
          "@KEY_HEIGHT_INC@"
          "@OUTPUTS@"
          "@WORKSPACES@"
          "@APP_WINDOW_RULES@"
          "@CURSOR_THEME@"
          "@CURSOR_SIZE@"
        ]
        [
          keys.help
          keys.consumeL
          keys.consumeR
          keys.widthDec
          keys.widthInc
          keys.heightDec
          keys.heightInc
          osConfig.host.desktop.niriOutputs
          workspacesKdl
          appWindowRulesKdl
          config.home.pointerCursor.name
          (toString config.home.pointerCursor.size)
        ]
        (builtins.readFile ./niri.kdl);
    };
}
