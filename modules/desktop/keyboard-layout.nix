{
  flake.modules.nixos.desktop = { config, lib, ... }: {
    options.lansing.desktop.keyboardLayout = lib.mkOption {
      type = lib.types.enum [ "ansi" "iso" ];
      default = "ansi";
      description = ''
        Physical keyboard layout. Drives services.xserver.xkb.layout
        (ansi -> us, iso -> de), the TTY console keymap (ansi -> us,
        iso -> de), and remaps niri keybindings whose keysyms (Slash,
        Equal, BracketLeft/Right) move to awkward positions under the
        German XKB layout.
      '';
    };

    options.lansing.desktop.niriOutputs = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Host-specific niri `output { … }` blocks. Injected into
        ~/.config/niri/config.kdl at the @OUTPUTS@ marker by the
        home-manager half of modules/desktop/niri.nix. Set per host
        (battlestation has DP-1 ultrawide, workstation has eDP-1 HiDPI).
      '';
    };

    config.console.keyMap =
      if config.lansing.desktop.keyboardLayout == "iso" then "de" else "us";
  };
}
