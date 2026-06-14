# Home-manager ↔ NixOS coupling, user-agnostic. Enables home-manager as a
# NixOS module and attaches each homeManager.<bucket> to every user a host
# registered in `my.homeUsers`. User aspects (modules/users/<name>.nix)
# self-register there, so a host gains a home-managed user purely by importing
# that user's nixos.user-<name> bucket — there is no per-user wiring here.
{ config, lib, inputs, ... }:
let
  hm = config.flake.modules.homeManager;
  # Attach a homeManager role bucket to every registered home user. Sits on
  # the nixos.<role> side so importing the role hands the bucket to all the
  # host's users; merges with that role's system-level definitions.
  attachRole = bucket: { config, ... }: {
    home-manager.users = lib.genAttrs config.my.homeUsers (_: { imports = [ bucket ]; });
  };
in
{
  flake.modules.nixos.base = { config, lib, ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    options.my.homeUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        OS users that receive home-manager. A user aspect appends itself here
        (see modules/users/lansing.nix), so the base home bucket and the role
        buckets attach automatically. Empty on a host that imports no user
        aspect — home-manager then manages nobody.
      '';
    };

    options.my.primaryUser = lib.mkOption {
      type = lib.types.str;
      description = ''
        The single OS user that owns this host's personal, single-owner
        bindings: the git identity / API-key / sunshine sops secrets and the
        like. Generic modules read this instead of hard-coding a username
        (see modules/system/sops.nix, modules/gaming/sunshine.nix).

        A user aspect sets it via mkUser (`lib.mkDefault username`), so a
        single-user host derives it automatically. A host that imports several
        user aspects must set it explicitly — the conflicting defaults fail
        otherwise, which is a deliberate prompt to choose the owner. For
        "every interactive user" bindings (e.g. polkit) use my.homeUsers.
      '';
    };

    config = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users = lib.genAttrs config.my.homeUsers (_: { imports = [ hm.base ]; });
    };
  };

  flake.modules.nixos.desktop = attachRole hm.desktop;
  flake.modules.nixos.development = attachRole hm.development;
}
