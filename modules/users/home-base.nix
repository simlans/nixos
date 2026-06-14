# User-agnostic home-manager defaults — applied to every user listed in
# `my.homeUsers` via the nixos.base coupling. Per-user identity (username,
# personal config) lives in the individual user aspects (homeManager.<name>);
# whatever is identical for everyone lives here.
{
  flake.modules.homeManager.base = { pkgs, ... }: {
    home.stateVersion = "25.11";

    # Adwaita's xcursor only ships sizes 24/30/36/48/72/96, so any size <24
    # silently rounds up to 24 (= niri's default). Catppuccin mocha dark adds
    # 12/18 at the small end and matches the Catppuccin scheme used elsewhere.
    home.pointerCursor = {
      package = pkgs.catppuccin-cursors.mochaDark;
      name = "catppuccin-mocha-dark-cursors";
      size = 16;
      gtk.enable = true;
    };

    programs.home-manager.enable = true;
  };
}
