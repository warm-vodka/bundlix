{ lib, mkEnableModule }:
{ root, prefix }:
let
  directories =
    path: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));
  categories = directories root;

  # Only <category>/<name>/default.nix entries are bundles. Sibling helper files
  # and directories without an entry point are left alone.
  discoverCategory =
    category:
    let
      categoryRoot = root + "/${category}";
    in
    lib.concatMap (
      name:
      let
        directory = categoryRoot + "/${name}";
        entryType = (builtins.readDir directory)."default.nix" or null;
      in
      lib.optional (entryType == "regular") {
        file = directory + "/default.nix";
        path = [
          category
          name
        ];
      }
    ) (directories categoryRoot);

  wrapBundle =
    { file, path }:
    args@{ config, ... }:
    let
      category = builtins.head path;
      bundleName = lib.concatStringsSep "." path;

      # Resolve function arguments just like other bundle modules: caller values
      # take precedence over deferred _module.args. Attribute sets need no call.
      evaluateBundle =
        bundle:
        let
          moduleArgs = lib.mapAttrs (name: _: args.${name} or config._module.args.${name}) (
            builtins.functionArgs bundle
          );
        in
        if builtins.isFunction bundle then bundle moduleArgs else bundle;

      prepareRequirements =
        bundle:
        let
          requires = bundle.requires or [ ];
          validRequires = builtins.isList requires && builtins.all builtins.isString requires;
          configuration = removeAttrs bundle [ "requires" ];

          # Bare names stay in this category; qualified names use categories
          # discovered from the root, not a fixed platform or category list.
          resolveRequirement =
            requirement:
            let
              segments = lib.splitString "." requirement;
              isLocal = builtins.length segments == 1 && requirement != "";
              isQualified =
                builtins.length segments == 2
                && builtins.elem (builtins.head segments) categories
                && lib.last segments != "";
            in
            if isLocal then
              [
                category
                requirement
              ]
            else if isQualified then
              segments
            else
              throw "invalid requirement '${requirement}' in bundle ${bundleName}; use <name> or <category>.<name>";

          requiredOptions = map (
            requirement: prefix ++ resolveRequirement requirement ++ [ "enable" ]
          ) requires;
          isEnabled = option: lib.hasAttrByPath option config && lib.getAttrFromPath option config;
          optionNames = map (lib.concatStringsSep ".") requiredOptions;
        in
        if !validRequires then
          throw "requires in bundle ${bundleName} must be a list of strings"
        else if requires == [ ] then
          configuration
        else
          configuration
          // {
            # The enable gate covers these checks too. Evaluate them only after
            # bundle merging, so dependencies do not force module recursion.
            _bundlix.requirements = [
              {
                assertion = lib.all isEnabled requiredOptions;
                message = "bundle ${bundleName} requires enabled bundle(s): ${lib.concatStringsSep ", " optionNames}";
              }
            ];
          };

      # Validate metadata even for a disabled bundle, before wrapping defers it.
      makeOptional =
        configuration: builtins.seq configuration (mkEnableModule (prefix ++ path) configuration);
    in
    lib.pipe (import file) [
      evaluateBundle
      prepareRequirements
      makeOptional
    ];
in
map wrapBundle (lib.concatMap discoverCategory categories)
