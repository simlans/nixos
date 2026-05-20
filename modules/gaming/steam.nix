{ ... }:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  hardware.graphics.enable32Bit = true;

  # Steam runs through XWayland (xwayland-satellite); niri reports the
  # X11 WM_CLASS as the app-id. The main client window is `Steam`,
  # while the small login/update splash uses `steam` — the regex
  # catches both. Game windows have their own app-ids and are not
  # captured by this rule, which matches what we want: the launcher
  # lives on `gaming`, individual games stay wherever they're spawned.
  lansing.desktop.niri.appWindowRules = [
    {
      match.app-id = "^[Ss]team$";
      openOnWorkspace = "gaming";
    }
    # Steam opens two windows: the main client and the friends list.
    # Niri's global default-column-width is 0.5, so both land at 50/50.
    # Force a sidebar layout: friends list slim on the left, main client
    # filling the rest. Titles are matched on the German locale ("Freunde",
    # "Freundesliste") and English ("Friends", "Friends List"); the main
    # window's title is just "Steam".
    {
      match = {
        app-id = "^Steam$";
        title = "^Steam$";
      };
      defaultColumnWidthProportion = 0.85;
    }
    {
      match = {
        app-id = "^Steam$";
        title = "^(Freunde|Freundesliste|Friends|Friends List)$";
      };
      defaultColumnWidthProportion = 0.15;
    }
  ];
}
