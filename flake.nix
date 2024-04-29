{
  description = "My Personal Laptop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
        url = "github:LnL7/nix-darwin";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, nix-homebrew }:
  let
    configuration = { pkgs, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = with pkgs; [
        micro
      ];

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true;  # default shell on catalina
      # programs.fish.enable = true;

      system = {
        # Set Git commit hash for darwin-version.
        configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility, please read the changelog before changing.
        # $ darwin-rebuild changelog
        stateVersion = 4;

        defaults = {
          ActivityMonitor = {
            # Change the icon in the dock when running.
            IconType = 5;
            # Change which processes to show. Set to 101: 'All Processes, Hierarchally'
            ShowCategory = 101;
            # Which column to sort the main activity page (such as "CPUUsage"). Default is null.
            SortColumn = "CPUUsage";
            # The sort direction of the sort column (0 is decending). Default is null.
            SortDirection = 0;
          };
          NSGlobalDomain = {
            # Sets the level of font smoothing (sub-pixel font rendering).
            AppleFontSmoothing = 2;
            # Whether to automatically switch between light and dark mode. The default is false.
            AppleInterfaceStyleSwitchesAutomatically = true;
            # Jump to the spot that's clicked on the scroll bar. The default is false.
            AppleScrollerPagingBehavior = true;
            # Whether to show all file extensions in Finder. The default is false.
            AppleShowAllExtensions = true;
            # Whether to always show hidden files. The default is false.
            AppleShowAllFiles = true;
            # When to show the scrollbars. Options are 'WhenScrolling', 'Automatic' and 'Always'.
            AppleShowScrollBars = "WhenScrolling";
            # Whether to enable automatic capitalization. The default is true.
            NSAutomaticCapitalizationEnabled = false;
            # Whether to enable smart dash substitution. The default is true.
            NSAutomaticDashSubstitutionEnabled = false;
            # Whether to enable smart quote substitution. The default is true.
            NSAutomaticQuoteSubstitutionEnabled = false;
            # Whether to enable automatic spelling correction. The default is true.
            NSAutomaticSpellingCorrectionEnabled = false;
            # Whether to use expanded save panel by default. The default is false.
            NSNavPanelExpandedStateForSaveMode = true;
            NSNavPanelExpandedStateForSaveMode2 = true;
            # Whether to enable moving window by holding anywhere on it like on Linux. The default is false.
            NSWindowShouldDragOnGesture = true;
            # Whether to use the expanded print panel by default. The default is false.
            PMPrintingExpandedStateForPrint = true;
            PMPrintingExpandedStateForPrint2 = true;
            # Whether to enable "Natural" scrolling direction. The default is true.
            "com.apple.swipescrolldirection" = false;
            # Configures the trackpad corner click behavior. Mode 1 enables right click.
            "com.apple.trackpad.trackpadCornerClickBehavior" = 1;
          };
          dock = {
            # Whether to automatically hide and show the dock. The default is false.
            autohide = true;
            # Magnify icon on hover. The default is false.
            magnification = true;
            # Position of the dock on screen. The default is "bottom".
            orientation = "left";
            # Whether to make icons of hidden applications tranclucent. The default is false.
            showhidden = true;
            # Show only open applications in the Dock. The default is false.
            static-only = true;
            # Hot corner action for top left corner. Set to 10: Put Display to Sleep
            wvous-tl-corner = 10;
          };
          finder = {
            # Whether to show all filename extensions. The default is false.
            AppleShowAllExtensions = true;
            # Whether to always show hidden files. The default is false.
            AppleShowAllFiles = true;
            # Change the default search scope. Use "SCcf" to default to current folder. The default is unset ("This Mac").
            FXDefaultSearchScope = "SCcf";
            # Change the default finder view. "icnv" = Icon view, "Nlsv" = List view, "clmv" = Column View, "Flwv" = Gallery View The default is icnv.
            FXPreferredViewStyle = "Nlsv";
            # Whether to allow quitting of the Finder. The default is false.
            QuitMenuItem = true;
            # Show path breadcrumbs in finder windows. The default is false.
            ShowPathbar = true;
            # Show status bar at bottom of finder windows with item/disk space stats. The default is false.
            ShowStatusBar = true;
            # Whether to show the full POSIX filepath in the window title. The default is false.
            _FXShowPosixPathInTitle = true;
          };
          screencapture = {
            # The filesystem path to which screencaptures should be written.
            location = "/Users/derick/Pictures/Screenshots";
            # The image format to use, such as "jpg".
            type = "png";
          };
          trackpad = {
            # Whether to enable tap-to-drag. The default is false.s
            Dragging = true;
            #Whether to enable trackpad right click. The default is false.
            TrackpadRightClick = true;
          };
        };
      };

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "x86_64-darwin";

      # Declare the user that will be running `nix-darwin`.
      users.users.derick = {
        name = "derick";
        home = "/Users/derick";
      };

      # Enable touch ID for sudo
      security.pam.enableSudoTouchIdAuth = true;
    };
    homeconfig = {pkgs, ...}: {
      # this is internal compatibility configuration
      # for home-manager, don't change this!
      home.stateVersion = "23.05";
      # Let home-manager install and manage itself.
      programs.home-manager.enable = true;

      home.packages = with pkgs; [
        age
        age-plugin-yubikey
        bat
        bat-extras.batman
        bat-extras.prettybat
        chezmoi
        darwin.trash
        delta
        dive
        eza
        fd
        fx
        fzf
        httpie
        imagemagick
        ldns
        libheif
        mas
        mcfly
        mosh
        neovim
        p7zip
        procs
        ripgrep
        rsync
        sad
        sd
        shellcheck
        tailscale
        tealdeer
        thefuck
        up
        xdg-ninja
        yt-dlp
        yubikey-manager
        zellij
        zoxide
      ];
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#Dericks-MacBook-Pro
    darwinConfigurations."Dericks-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        home-manager.darwinModules.home-manager  {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.verbose = true;
          home-manager.users.derick = homeconfig;
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Dericks-MacBook-Pro".pkgs;
  };
}
