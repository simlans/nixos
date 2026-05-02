{ ... }:
{
  programs.firefox = {
    enable = true;

    # Force-install the 1Password browser extension via Firefox enterprise
    # policy. The extension talks to the desktop app over native messaging,
    # which `modules/apps/onepassword.nix` already wires up through
    # `programs._1password-gui`.
    policies.ExtensionSettings = {
      "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
      };
    };
  };
}
