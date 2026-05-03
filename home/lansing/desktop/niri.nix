{ osConfig, ... }:
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
    ]
    [
      keys.help
      keys.consumeL
      keys.consumeR
      keys.widthDec
      keys.widthInc
      keys.heightDec
      keys.heightInc
    ]
    (builtins.readFile ./niri.kdl);
}
