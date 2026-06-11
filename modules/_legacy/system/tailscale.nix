{ ... }:
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  # Auth key bootstrap: `nix run .#tailscale-up` (defined in flake.nix).
}
