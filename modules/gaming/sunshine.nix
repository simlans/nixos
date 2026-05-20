{ config, lib, pkgs, ... }:
{
  # Sunshine = Moonlight game-streaming host. Streams the desktop and game
  # sessions to any Moonlight client (TV, phone, laptop) over LAN or
  # Tailscale. The `services.sunshine` module in nixpkgs already wires the
  # firewall, the CAP_SYS_ADMIN wrapper, /dev/uinput udev rules, the avahi
  # mDNS announcement, and the systemd user unit tied to
  # graphical-session.target. We only feed it settings, the apps list, and
  # an ExecStartPre that seeds the WebUI admin credentials from sops.
  #
  # `lansing` is already in the `input` group (modules/system/users.nix),
  # so /dev/uinput access via Sunshine's bundled udev rule (`TAG+="uaccess"`)
  # works without further wiring.
  #
  # Sops secrets are declared locally in this module rather than in
  # modules/system/sops.nix so that only hosts importing this module (i.e.
  # battlestation) actually decrypt them into /run/secrets/.

  sops.secrets."sunshine/admin_user".owner = "lansing";
  sops.secrets."sunshine/admin_pass".owner = "lansing";

  services.sunshine = {
    enable = true;

    # Opens TCP 47984/47989/47990/48010 + UDP 47998/47999/48000/48002/48010
    # (computed as offsets from settings.port = 47989 inside the upstream
    # module).
    openFirewall = true;

    # kmsgrab needs CAP_SYS_ADMIN on the binary; the upstream module
    # installs a `security.wrappers.sunshine` entry when this is true.
    capSysAdmin = true;

    settings = {
      sunshine_name = "battlestation";

      # AMD RDNA 4 (RX 9070 XT / VCN 5.0) → VA-API via the radeonsi
      # render node. AMF userspace is not part of the open Linux stack;
      # VA-API is the supported HW encoder path. Sunshine 2025.x has
      # known HEVC scaling artifacts on radeonsi, so leave the encoder
      # default-codec (H.264) — switch the codec from the Moonlight
      # client if you want to experiment with HEVC/AV1 later.
      encoder = "vaapi";
      adapter_name = "/dev/dri/renderD128";

      # KMS capture works on any DRM-backed Wayland compositor incl.
      # niri. wlr-screencopy isn't enough — niri isn't wlroots-based,
      # and only KMS carries HDR and accurate cursor frames.
      capture = "kms";

      # The battlestation runs the ultrawide on DP-1
      # (hosts/battlestation/default.nix → lansing.desktop.niriOutputs).
      # DRM connector names match niri output names.
      output_name = "DP-1";

      # Keep the journal quiet; the WebUI shows verbose logs anyway.
      min_log_level = "warning";
    };

    applications.apps = [
      {
        name = "Desktop";
        image-path = "desktop.png";
      }
    ] ++ lib.optionals config.programs.steam.enable [
      {
        name = "Steam Big Picture";
        # `setsid -f` detaches Steam from Sunshine's process group;
        # Steam's self-updater kills its own parent, which would
        # otherwise take the Sunshine session bookkeeping down with it.
        # The user unit's PATH is forced null upstream (tray icon
        # compatibility), so absolute paths are mandatory.
        detached = [
          "${pkgs.util-linux}/bin/setsid -f ${pkgs.steam}/bin/steam steam://open/bigpicture"
        ];
        image-path = "steam.png";
      }
    ];
  };

  # Seed the WebUI admin credentials non-interactively on every start.
  # `sunshine --creds` is the upstream-supported path (see
  # nixos/tests/sunshine.nix in nixpkgs). Idempotent — rewrites
  # sunshine_state.json with the same creds on each restart; the salt
  # rotates on every invocation, which is cosmetic. Absolute paths
  # because the user unit clears PATH upstream.
  systemd.user.services.sunshine.serviceConfig.ExecStartPre =
    let
      seed = pkgs.writeShellScript "sunshine-seed-creds" ''
        set -eu
        user=$(${pkgs.coreutils}/bin/cat "${config.sops.secrets."sunshine/admin_user".path}")
        pass=$(${pkgs.coreutils}/bin/cat "${config.sops.secrets."sunshine/admin_pass".path}")
        ${lib.getExe pkgs.sunshine} --creds "$user" "$pass" >/dev/null 2>&1
      '';
    in
    [ "${seed}" ];
}
