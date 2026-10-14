{ bundleInfo, ... }:
{
  features.programs.git.enable = true;

  nixos =
    { inputs, ... }:
    {
      # A VM supplies its own filesystems and boot configuration. Replace this
      # import with generated hardware configuration before using a real host.
      imports = [ "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];
      nixpkgs.hostPlatform = bundleInfo.system;
      networking.hostName = "demo";
      system.stateVersion = "26.05";
      virtualisation.graphics = false;

      users.users.demo = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };

      # These conveniences are for the demo VM only, not a production machine.
      services.getty.autologinUser = "demo";
      security.sudo.wheelNeedsPassword = false;
    };

  home-manager = {
    home = {
      username = "demo";
      homeDirectory = "/home/demo";
      stateVersion = "26.05";
    };
    programs.home-manager.enable = true;
  };
}
