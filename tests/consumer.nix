{ lib }:
{
  autoImport ? {
    enable = true;
    root = ./fixtures/bundles;
    prefix = [ "features" ];
  },
  hosts ? {
    alpha = {
      system = "x86_64-linux";
      systemPlatform = "test";
    };
  },
  users ? {
    alice.hosts.alpha = { };
  },
  shared ? { },
  requirements ? [ "tools.peer" ],
  specialArgs ? { },
  homePlatforms ? null,
}:
let
  # A real custom platform: generated modules are evaluated by the Nix module
  # system, rather than inspected as unevaluated imports or mocked outputs.
  homeModule = {
    options.events = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };
  homesModule = {
    options.homes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submoduleWith { modules = [ homeModule ]; });
      default = { };
    };
  };
  defaultHomePlatforms.home = {
    namespace = "home";
    system = {
      usersAttrPath = [ "homes" ];
      platforms.test.module = homesModule;
    };
  };
in
lib.evalModules {
  specialArgs = {
    inputs.self = { };
    self = { };
    getSystem = system: { allModuleArgs = { inherit system; }; };
  };
  modules = [
    ../module
    {
      options.flake = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
      config.bundle = {
        inherit
          autoImport
          hosts
          users
          shared
          ;
        specialArgs = {
          inherit requirements;
        }
        // specialArgs;
        systemPlatforms = lib.mkForce {
          test = {
            namespace = "system";
            flakeAttribute = "testConfigurations";
            mkSystem = args: (lib.evalModules args).config;
            extraConfig = _: {
              options.events = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
            };
          };
        };
        homePlatforms = lib.mkForce (if homePlatforms == null then defaultHomePlatforms else homePlatforms);
      };
    }
  ];
}
