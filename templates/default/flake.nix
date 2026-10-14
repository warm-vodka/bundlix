{
  description = "A NixOS and Home Manager configuration using bundlix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    bundlix.url = "github:warm-vodka/bundlix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.bundlix.flakeModules.default ];
      systems = [ "x86_64-linux" ];

      bundle = {
        autoImport = {
          enable = true;
          root = ./bundles;
          prefix = [ "features" ];
        };

        hosts.demo = {
          system = "x86_64-linux";
          systemPlatform = "nixos";
        };

        users.demo.hosts.demo.imports = [ ./hosts/demo.nix ];
      };
    };
}
