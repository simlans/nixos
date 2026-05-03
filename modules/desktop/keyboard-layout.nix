{ lib, ... }:
{
  options.lansing.desktop.keyboardLayout = lib.mkOption {
    type = lib.types.enum [ "ansi" "iso" ];
    default = "ansi";
    description = ''
      Physical keyboard layout. Drives services.xserver.xkb.layout
      (ansi -> us, iso -> de) and remaps niri keybindings whose keysyms
      (Slash, Equal, BracketLeft/Right) move to awkward positions under
      the German XKB layout.
    '';
  };
}
