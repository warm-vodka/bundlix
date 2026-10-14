bundleLib:
{ lib, config, ... }:
let
  inherit (lib) types;
  cfg = config.bundle.autoImport;
in
{
  options.bundle.autoImport = {
    enable = lib.mkEnableOption "automatic discovery of optional bundles";

    root = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      example = lib.literalExpression "./bundles";
      description = "Directory containing <category>/<name>/default.nix bundle entries. Required when auto-importing is enabled";
    };

    prefix = lib.mkOption {
      type = types.listOf types.str;
      default = [ "bundles" ];
      example = [
        "myConfig"
        "features"
      ];
      description = "Attribute path prepended to each generated <category>.<name>.enable option. These options belong to bundle configuration, not platform configuration";
    };

    modules = lib.mkOption {
      type = types.listOf types.deferredModule;
      internal = true;
      visible = false;
      readOnly = true;
      description = "Discovered optional bundle modules shared by all host and user evaluations";
    };
  };

  # Do not inspect root when disabled. Discovery belongs to the parent module,
  # so a bundle's own enable flags cannot change its imports during evaluation.
  config.bundle.autoImport.modules =
    if !cfg.enable then
      [ ]
    else if cfg.root == null then
      throw "bundle.autoImport.root must be set when bundle.autoImport.enable is true"
    else
      bundleLib.mkOptionalBundles { inherit (cfg) root prefix; };
}
