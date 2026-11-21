# Niri desktop (D-05). The niri config itself is a chezmoi dotfile
# (~/.config/niri/config.kdl); this only installs the pieces.
{
  flake.modules.nixos.niri =
    { pkgs, ... }:
    {
      programs.niri.enable = true;

      services.greetd = {
        enable = true;
        settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
      };

      security.polkit.enable = true;
      security.rtkit.enable = true;
      services.gnome.gnome-keyring.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      # Electron and Chromium apps run as native Wayland clients.
      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      environment.systemPackages = with pkgs; [
        xwayland-satellite # X11 apps (niri starts it on demand)
        alacritty # niri's default config binds Mod+T to alacritty
        fuzzel
        waybar
        mako
        swaylock
        swayidle
        wl-clipboard
        polkit_gnome
      ];

      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-color-emoji
        nerd-fonts.jetbrains-mono
      ];
    };
}
