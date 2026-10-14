{ lib, getSystem }:
let
  bundleLib = {
    mkEnableModule =
      optionPath: moduleConfig:
      let
        enableOptionPath = optionPath ++ [ "enable" ];
      in
      {
        imports = lib.singleton (
          { config, ... }:
          {
            options = lib.setAttrByPath enableOptionPath (lib.mkEnableOption "${lib.last optionPath} config");
            config = lib.mkIf (lib.getAttrFromPath enableOptionPath config) moduleConfig;
          }
        );
      };

    mkOptionalBundles = import ./lib/optional-bundles.nix {
      inherit lib;
      inherit (bundleLib) mkEnableModule;
    };

    # Check fully merged bundles, not individual module definitions. This works
    # for every platform and keeps disabled bundles' requirements inactive.
    checkBundleRequirements =
      bundles: value:
      let
        checks = lib.concatMap (bundle: bundle._bundlix.requirements) bundles;
        failed = lib.filter (check: !check.assertion) checks;
        messages = lib.unique (map (check: check.message) failed);
      in
      if failed == [ ] then
        value
      else
        throw "bundle requirements failed:\n${lib.concatStringsSep "\n" messages}";

    transpose =
      let
        deconstruct = lib.mapAttrsToList (
          parentAttr: children:
          lib.mapAttrsToList (childAttr: value: {
            ${childAttr}.${parentAttr} = value;
          }) children
        );

        reconstruct = builtins.zipAttrsWith (_: lib.mergeAttrsList);
      in
      attrs:
      lib.pipe attrs [
        deconstruct
        lib.flatten
        reconstruct
      ];

    withSystemExtraArgs =
      system: args: f:
      f ((getSystem system).allModuleArgs // args);
  };
in
bundleLib
