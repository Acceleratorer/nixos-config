# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, python310, ... }:

let
  mlCudaPackages = pkgs.cudaPackages.overrideScope (_: cudaPrev: {
    # PyTorch needs the NVSHMEM library, not its large test/example suite.
    libnvshmem = cudaPrev.libnvshmem.overrideAttrs (oldAttrs: {
      cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
        "-DNVSHMEM_BUILD_TESTS=OFF"
        "-DNVSHMEM_BUILD_EXAMPLES=OFF"
      ];
    });
  });
  androidPackages = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "latest" ];
    buildToolsVersions = [ "latest" ];
    includeCmake = false;
    includeEmulator = false;
    includeNDK = false;
    includeSystemImages = false;
  };
  androidStudio = pkgs.android-studio.withSdk androidPackages.androidsdk;
in

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./desktop-hyprland.nix
      ./desktop/regreet
    ];

  # Keep the second internal SSD available as /mnt/data without blocking boot
  # if the drive is temporarily unavailable.
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/3EE2FC81E2FC3F29";
    fsType = "ntfs3";
    options = [
      "nofail"
      "x-systemd.device-timeout=5s"
      "uid=1000"
      "gid=100"
      "umask=022"
    ];
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 50;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Ho_Chi_Minh";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "vi_VN";
    LC_IDENTIFICATION = "vi_VN";
    LC_MEASUREMENT = "vi_VN";
    LC_MONETARY = "vi_VN";
    LC_NAME = "vi_VN";
    LC_NUMERIC = "vi_VN";
    LC_PAPER = "vi_VN";
    LC_TELEPHONE = "vi_VN";
    LC_TIME = "vi_VN";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = false;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."accelra" = {
    isNormalUser = true;
    description = "accelra";
    extraGroups = [ "networkmanager" "wheel" "docker" "kvm" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages and build CUDA libraries only for this GPU.
  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
    cudaCapabilities = [ "8.6" ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.sessionVariables = {
    ANDROID_HOME = "${androidPackages.androidsdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidPackages.androidsdk}/libexec/android-sdk";
    JAVA_HOME = "${pkgs.jdk17}";
  };

  # Container and local-cluster tooling.
  virtualisation.docker.enable = true;

  # Local single-node Kafka broker for development.
  services.apache-kafka = {
    enable = true;
    clusterId = "um-MdL6BSf6pam9fNRWu2w";
    formatLogDirs = true;
    jvmOptions = [
      "-Xms256m"
      "-Xmx768m"
    ];
    settings = {
      "node.id" = 1;
      "process.roles" = [
        "broker"
        "controller"
      ];
      listeners = [
        "PLAINTEXT://127.0.0.1:9092"
        "CONTROLLER://127.0.0.1:9093"
      ];
      "advertised.listeners" = [ "PLAINTEXT://127.0.0.1:9092" ];
      "listener.security.protocol.map" = [
        "PLAINTEXT:PLAINTEXT"
        "CONTROLLER:PLAINTEXT"
      ];
      "controller.quorum.voters" = [ "1@127.0.0.1:9093" ];
      "controller.listener.names" = [ "CONTROLLER" ];
      "inter.broker.listener.name" = "PLAINTEXT";
      "log.dirs" = [ "/var/lib/apache-kafka" ];
      "num.partitions" = 3;
      "default.replication.factor" = 1;
      "min.insync.replicas" = 1;
      "offsets.topic.replication.factor" = 1;
      "transaction.state.log.replication.factor" = 1;
      "transaction.state.log.min.isr" = 1;
    };
  };
  systemd.services.apache-kafka.serviceConfig.StateDirectory = "apache-kafka";

  nix.gc = {
    automatic = true;
    dates = "Sun 03:15";
    options = "--delete-older-than 30d";
    randomizedDelaySec = "1h";
  };

  nix.optimise = {
    automatic = true;
    dates = "Mon 03:45";
  };

  services.asusd.enable = true;
  services.asusd.auraConfigs."1866".source = ./asusd/aura_1866.ron;
  systemd.services.asusd.serviceConfig.ConfigurationDirectory = "asusd";
  services.supergfxd.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.finegrained = true;
    dynamicBoost.enable = false;

    prime = {
      amdgpuBusId = "PCI:6@0:0:0";
      nvidiaBusId = "PCI:1@0:0:0";

      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  environment.systemPackages = with pkgs; [

	brave
	vscode
	asusctl 
  	git 
	gh
  	nodejs
	(pkgs.callPackage ./packages/codex.nix { })
	discord
	obsidian
	p7zip
	rar
	bubblewrap

	# Containers and Kubernetes.
	docker-compose
	kubectl
	kind
	minikube
	kubernetes-helm
	k9s

	# Streaming and event pipelines.
	apacheKafka
	kcat

	# Kaggle CLI for datasets, notebooks, competitions, models, and benchmarks.
	kaggle

	# Developer essentials.
	ripgrep
	fd
	jq
	yq
	tmux
	direnv
	git-lfs
	pre-commit
	just
	uv
	ruff

	# Local data and media tools.
	blender
	duckdb
	sqlite
	mpv
	ffmpeg
	yt-dlp

	# Container, backup, and cloud utilities.
	lazydocker
	restic
	rclone

	# Desktop communication.
	telegram-desktop

	# Document tools: PDF reader and Microsoft Office-compatible editor.
	evince
	libreoffice-fresh
	pdfarranger
	xournalpp
	texstudio
	texlive.combined.scheme-medium

	# Android development.
	androidStudio
	androidPackages.androidsdk
	jdk17
	dotnet-sdk_9
	kotlin
	gradle

	# CUDA-enabled machine-learning environment.
	cudaPackages.cudatoolkit
	(python3.withPackages (ps:
	  let
	    torchCuda = ps.torch-bin.override { cudaPackages = mlCudaPackages; };
	    torchvisionCuda = ps.torchvision-bin.override {
	      cudaPackages = mlCudaPackages;
	      torch-bin = torchCuda;
	    };
	    accelerateCuda = ps.accelerate.override {
	      torch = torchCuda;
	      torchvision = torchvisionCuda;
	    };
	    peftCuda = ps.peft.override {
	      accelerate = accelerateCuda;
	      torch = torchCuda;
	    };
	    sentenceTransformersCuda = ps.sentence-transformers.override {
	      accelerate = accelerateCuda;
	      torch = torchCuda;
	    };
	  in [
	    ps.numpy
	    ps.pandas
	    ps.polars
	    ps.scipy
	    ps.scikit-learn
	    ps.matplotlib
	    ps.seaborn
	    ps.jupyterlab
	    ps.ipykernel
	    ps.transformers
	    ps.datasets
	    ps.opencv-python
	    ps.scikit-image
	    ps.xgboost
	    ps.lightgbm
	    ps.statsmodels
	    ps.optuna
	    ps.imbalanced-learn
	    ps.plotly
	    ps.openpyxl
	    ps.duckdb
	    accelerateCuda
	    peftCuda
	    sentenceTransformersCuda
	    ps.onnx
	    ps.onnxruntime
	    torchvisionCuda
	    torchCuda
	    ps.tensorflowWithCuda
	  ]))

	# Compatibility interpreter for projects that have not adopted Python 3.13.
	python310
	(writeShellScriptBin "py310" ''
	  exec ${python310}/bin/python3.10 "$@"
	'')

  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans 
    noto-fonts-color-emoji    
    liberation_ttf     
    fira-code           
    fira-code-symbols
  ];
  
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
