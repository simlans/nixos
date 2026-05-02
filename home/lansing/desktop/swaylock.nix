{ pkgs, ... }:
{
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      screenshots = true;
      effect-blur = "20x3";
      effect-vignette = "0.5:0.5";
      clock = true;
      timestr = "%H:%M";
      datestr = "%a, %d %b";
      indicator = true;
      indicator-radius = 110;
      indicator-thickness = 8;
      font-size = 28;
      fade-in = "0.2";
      ring-color = "3b4252";
      key-hl-color = "88c0d0";
      line-color = "00000000";
      inside-color = "00000088";
      separator-color = "00000000";
      text-color = "eceff4";
      ring-clear-color = "ebcb8b";
      inside-clear-color = "00000088";
      text-clear-color = "eceff4";
      ring-ver-color = "5e81ac";
      inside-ver-color = "00000088";
      text-ver-color = "eceff4";
      ring-wrong-color = "bf616a";
      inside-wrong-color = "00000088";
      text-wrong-color = "eceff4";
    };
  };
}
