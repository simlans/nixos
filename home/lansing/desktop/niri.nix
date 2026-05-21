{ config, lib, osConfig, ... }:
let
  keys =
    if osConfig.lansing.desktop.keyboardLayout == "iso" then {
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

  niriCfg = osConfig.lansing.desktop.niri;

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
      osConfig.lansing.desktop.niriOutputs
      workspacesKdl
      appWindowRulesKdl
      config.home.pointerCursor.name
      (toString config.home.pointerCursor.size)
    ]
    (builtins.readFile ./niri.kdl);
}
