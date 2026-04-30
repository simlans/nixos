{ ... }:
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # Auth key is *not* baked into the flake. After the first rebuild,
  # bootstrap the node interactively as root with:
  #   tailscale up \
  #     --auth-key="$(op read 'op://nixos/tailscale-authkey/credential')" \
  #     --accept-dns --accept-routes
  # The node identity is then persisted under /var/lib/tailscale and
  # subsequent rebuilds don't need the key again.
}
