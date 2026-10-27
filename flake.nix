{
  description = "bundle-of-nix";

  outputs =
    _:
    let
      flakeModules = {
        bundle = import ./module;
        default = flakeModules.bundle;
      };
    in
    {
      inherit flakeModules;

      templates.default = {
        path = ./templates/default;
        description = "NixOS and Home Manager with optional bundle auto-importing";
        welcomeText = ''
          # bundlix

          Run the demo VM:

          ```sh
          nix run .#nixosConfigurations.demo.config.system.build.vm
          ```

          Optional bundles live in `bundles/<category>/<name>/*.nix`.
          Set their `features.<category>.<name>.enable` flags in `hosts/demo.nix`.

          The demo VM uses console autologin and passwordless sudo. Replace its
          VM import and review those settings before adapting it to real hardware.
        '';
      };
    };
}
