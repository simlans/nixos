{ ... }:
let
  # Nix has no \xNN / \u escape, so we round-trip through JSON to get the
  # literal ESC byte (0x1B). Sent together with \r this is the
  # ESC + CR sequence Claude Code interprets as "insert newline" — without
  # it, Shift+Enter is indistinguishable from Enter at the byte level and
  # just submits the prompt.
  esc = builtins.fromJSON ''"\u001b"'';
in
{
  programs.alacritty = {
    enable = true;
    settings.window.decorations = "None";
    settings.font = {
      size = 10;
      normal.family = "JetBrainsMono Nerd Font";
      bold.family = "JetBrainsMono Nerd Font";
      italic.family = "JetBrainsMono Nerd Font";
      bold_italic.family = "JetBrainsMono Nerd Font";
    };
    settings.keyboard.bindings = [
      {
        key = "Return";
        mods = "Shift";
        chars = "${esc}\r";
      }
    ];
  };
}
