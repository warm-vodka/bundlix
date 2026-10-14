# bundle

The coziest way to manage your nix config!

**bundle** is a [flake-parts](https://flake.parts/) module that groups your configuration into small, feature-focused modules called **bundles**. Each bundle can contain bits of config for multiple system platforms, such as NixOS and Darwin, and multiple home platforms, such as Home Manager and Hjem

#### Contents

- [The problem](#the-problem)
- [The solution](#the-solution-bundle)
- [When to use bundle](#when-to-use-bundle)
- [User-centric configuration](#user-centric-configuration)
- [Supported platforms](#supported-platforms)
- [Getting started](#getting-started)
- [Flake template](#flake-template)
- [Optional bundle auto-importing](#optional-bundle-auto-importing)

## The problem

Most (non **bundle**) configurations are typically platform focused, splitting up configuration files by platform:

```
darwin
├── fish.nix
└── hyprland.nix
home-manager
├── fish.nix
├── hyprland.nix
├── librewolf.nix
└── obs-studio.nix
nixos
├── fish.nix
├── hyprland.nix
└── obs-studio.nix
```

## The solution (bundle)

**bundle** unites your platforms under a single module system, giving you far more flexibility for whatever structure you want to use:

```
applications
├── librewolf.nix
└── obs-studio.nix
desktop
└── hyprland.nix
terminal
└── fish.nix
```

Here's a look at that OBS module, we're able to apply both nixos and home-manager configuration in one place

```nix
{
  nixos.programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  home-manager = { pkgs, ... }: {
    programs.obs-studio = {
      enable = true;
      plugins = [ pkgs.obs-studio-plugins.obs-move-transition ];
    };
  };
}
```

You could even wrap it with an enable option if you'd like to

```nix
{ lib, config, ... }:
{
  options.myConfig.applications.obs-studio.enable = lib.mkEnableOption "obs-studio config";

  config = lib.mkIf config.myConfig.applications.obs-studio.enable {
    nixos = { ... };
    home-manager = { ... };
  };
}
```

## When to use bundle

**bundle** is extensible and makes as little assumptions about how you like to do things as possible. This allows **bundle** to work well with:

- Single host, single user configs
- Multi host, multi user configs
- Option based pattern
- The dendritic pattern (import based config)
- Pure NixOS configs (i'm not sure why you're here)
- Everything in one file! (please don't)

But if you don't like grouping up configuration from different platforms, **bundle** is not for you

Bundle also does not currently support separate home platform builds, this means no `homeConfigurations`. Though this may be added soon

## User-centric configuration

In **bundle**, hosts are configured in the context of a user. This means configuration cannot be applied directly to a host:

```nix
{
  bundle.users = {
    diffy = {
      shared = { ... };
      hosts = {
        sodium = { ... };
        potassium = { ... };
      };
    };

    alice = {
      shared = { ... };
      hosts = {
        potassium = { ... };
        iodine = { ... };
      };
    };
  };
}
```

If a host is shared between multiple users, it will inherit configuration from both of those users

User-centric configuration like this allows for per user configuration (home-manager, etc) to be included in bundles, while maintaining multi-user support

## Supported platforms

**bundle** is platform agnostic & extensible through the [`systemPlatforms` & `homePlatforms`](module/platforms.nix) options, this means you can extend **bundle** to work with any system or home platform you'd like

Some platforms are configured by default, if a platform you want to use isn't included here, feel free to make an issue:

### Default system platforms

- [NixOS](https://github.com/NixOS/nixpkgs)
- Darwin ([nix-darwin](https://github.com/nix-darwin/nix-darwin))

### Default home platforms

- [Home Manager](https://github.com/nix-community/home-manager)
- [hjem](https://github.com/feel-co/hjem)

## Getting started

Firstly, configure the `system` & `systemPlatform` for each of your hosts:

```nix
{
  bundle = {
    hosts = {
      sodium = {
        system = "x86_64-linux";
        systemPlatform = "nixos";
      };
      potassium = {
        system = "x86_64-darwin";
        systemPlatform = "darwin";
      };
      iodine = {
        system = "x86_64-linux";
        systemPlatform = "nixos";
      };
    };
  };
}
```

Then add your configuration for each user, here's an example configuration:

```nix
{
  bundle = {
    hosts = { ... };

    users = {
      diffy = {
        shared = {
          imports = [ ./users/diffy/shared ];
          home-manager.home.username = "diffy";
        };
        hosts = {
          sodium = {
            imports = [ ./users/diffy/hosts/sodium ];
            nixos.networking.hostName = "sodium";
          };
          potassium = {
            imports = [ ./users/diffy/hosts/sodium ];
            nixos.networking.hostName = "potassium";
          };
        };
      };

      alice = { ... };
    };
  };
}
```

Based on your configuration, **bundle** will generate your hosts' configurations for you

## Flake template

Initialize the default template in an empty directory:

```sh
nix flake init -t github:warm-vodka/bundlix#default
```

The template uses flake-parts, NixOS, and Home Manager. It enables optional bundle
discovery under `bundles/` with the `features` prefix, includes a Git bundle, and
registers a `demo` user and host. Run its headless VM with:

```sh
nix run .#nixosConfigurations.demo.config.system.build.vm
```

This is a demo VM, not an installer or a hardware configuration. Console
autologin and passwordless sudo are enabled for convenience. Before adapting it
to a real machine, replace the QEMU VM import in `hosts/demo.nix` with generated
hardware configuration, review those login settings, and update the host/user
names and architecture.

Add bundles at `<category>/<name>/default.nix` and enable them from the host's
bundle configuration with `features.<category>.<name>.enable`.

## Optional bundle auto-importing

Auto-importing is opt-in. It discovers bundles and creates default-off enable
options; it does not enable the bundles themselves.

```nix
{
  bundle.autoImport = {
    enable = true;
    root = ./bundles;
    prefix = [ "features" ];
  };

  bundle.users.diffy.hosts.sodium = {
    features.programs.helix.enable = true;
    features.programs.wakatime.enable = true;
  };
}
```

The root uses this layout:

```text
bundles/
└── programs/
    ├── helix/
    │   ├── default.nix
    │   └── helper.nix
    └── wakatime/
        └── default.nix
```

Only `<category>/<name>/default.nix` entry points are imported. Categories are
inferred from directories directly under `root`; root-level files, sibling
helpers, and directories without an entry point are ignored. Directory symlinks
are not traversed, and entry points must be regular files.

| Option | Default | Purpose |
|---|---|---|
| `bundle.autoImport.enable` | `false` | Enable discovery of optional bundles |
| `bundle.autoImport.root` | `null` | Bundle root; required when discovery is enabled |
| `bundle.autoImport.prefix` | `[ "bundles" ]` | Attribute path prepended to generated enable options |

For example, `programs/helix/default.nix` with `prefix = [ "features" ]` creates
`features.programs.helix.enable`. A prefix can have multiple segments or be empty.
Keep it separate from platform namespaces and the internal `_bundlix` namespace.
Generated flags belong to **bundle configuration**, not inside `nixos`,
`darwin`, or `home-manager` configuration.

All host and per-user bundle evaluations register these options. Set flags in
`bundle.shared`, a user's `shared`, or a user's host configuration, using the
same scoping rules as other bundle configuration.

### Bundle contents and requirements

An entry point contains platform configuration, either as an attribute set or
as a function taking normal bundle arguments:

```nix
{ inputs', ... }:
{
  requires = [ "wakatime" ];
  home-manager.programs.helix = {
    enable = true;
    extraPackages = [ inputs'.wakatime-ls.packages.default ];
  };
}
```

`requires` is optional wrapper metadata and must be a list of strings. Bare
names refer to the same category; `"services.noctalia"` refers to another
category discovered under `root`. Requirement checks use the same prefix as
the generated enable options.

Requirements never enable dependencies. An enabled bundle with a missing or
disabled dependency fails evaluation and reports the required flag paths.
Disabled bundles do not enforce their requirements. Checks run after bundle
configuration has merged and apply to every system platform, not just NixOS.
Each user's requirements must also be satisfied in that user's configuration;
another user's flags cannot satisfy them.

The wrapper manages the enable option and `requires` metadata. Entry points
should return platform configuration, not their own top-level module
`options`, `config`, or `imports`. Platform modules can still have their own
imports, and sibling helper files can be imported explicitly from an entry.

### Migrating from manual wrapping

Enable `bundle.autoImport`, set the root, and set `prefix` to the attribute path
used by your existing enable flags. Remove the manual import-tree mapping or
`mkEnableModule` wrapping for those entries; auto-importing replaces that step.
Keep imports for core configuration and host/user configuration.

With auto-importing disabled, no root directory is read and manual imports work
as before. The feature reuses the `lib` supplied by flake-parts and does not add
flake inputs.
