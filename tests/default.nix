{ lib }:
let
  consumer = import ./consumer.nix { inherit lib; };
  root = ./fixtures/bundles;
  enabledFlags = {
    programs.editor.enable = true;
    tools.peer.enable = true;
  };
  enabledUsers.alice.hosts.alpha.features = enabledFlags;
  enabledAlpha = {
    events = [
      "editor"
      "editor-extra"
      "peer"
    ];
    homes.alice = [
      "editor"
      "editor-extra"
      "peer"
    ];
  };
  emptyAlpha = {
    events = [ ];
    homes = { };
  };

  # Compare the generated platform configuration, including per-user results.
  output =
    args:
    lib.mapAttrs (_: host: {
      events = lib.sort builtins.lessThan host.events;
      homes = lib.mapAttrs (_: home: lib.sort builtins.lessThan home.events) (host.homes or { });
    }) (consumer args).config.flake.testConfigurations;
  rejected =
    args:
    !(builtins.tryEval (builtins.deepSeq (consumer args).config.flake.testConfigurations true)).success;

  tests = {
    testDisabledWithoutRootPreservesManualConfiguration = {
      expr = output {
        autoImport = { };
        shared.system.events = [ "manual" ];
      };
      expected.alpha = {
        events = [ "manual" ];
        homes = { };
      };
    };
    testDisabledDoesNotReadRoot = {
      expr = output { autoImport.root = "/bundlix-test-directory-that-does-not-exist"; };
      expected.alpha = emptyAlpha;
    };
    testEnabledNeedsRoot = {
      expr = rejected { autoImport.enable = true; };
      expected = true;
    };
    testDiscoveredBundlesStayDisabled = {
      expr = output { };
      expected.alpha = emptyAlpha;
    };
    testNewCategoryDependencies = {
      expr = output { users = enabledUsers; };
      expected.alpha = enabledAlpha;
    };
    testDefaultPrefixAndExistingModuleLists = {
      expr = output {
        autoImport = {
          enable = true;
          inherit root;
        };
        users.alice.hosts.alpha.bundles.programs.plain.enable = true;
      };
      expected.alpha = {
        events = [
          "first"
          "second"
        ];
        homes = { };
      };
    };
    testBundleWithoutDefaultImportsAllFiles = {
      expr = output {
        users.alice.hosts.alpha.features = {
          programs.helpers.enable = true;
          tools.peer.enable = true;
        };
      };
      expected.alpha = {
        events = [
          "peer"
          "standalone"
        ];
        homes.alice = [
          "peer"
          "standalone"
        ];
      };
    };
    testNonDefaultFileEnforcesRequirements = {
      expr = rejected { users.alice.hosts.alpha.features.programs.helpers.enable = true; };
      expected = true;
    };
    testNestedPrefix = {
      expr = output {
        autoImport = {
          enable = true;
          inherit root;
          prefix = [
            "personal"
            "features"
          ];
        };
        users.alice.hosts.alpha.personal.features = enabledFlags;
      };
      expected.alpha = enabledAlpha;
    };
    testEmptyPrefix = {
      expr = output {
        autoImport = {
          enable = true;
          inherit root;
          prefix = [ ];
        };
        users.alice.hosts.alpha = enabledFlags;
      };
      expected.alpha = enabledAlpha;
    };
    testLocalRequirement = {
      expr = output {
        requirements = [ "plain" ];
        users.alice.hosts.alpha.features.programs = {
          editor.enable = true;
          plain.enable = true;
        };
      };
      expected.alpha = {
        events = [
          "editor"
          "editor-extra"
          "first"
          "second"
        ];
        homes.alice = [
          "editor"
          "editor-extra"
        ];
      };
    };
    testDisabledDependency = {
      expr = rejected { users.alice.hosts.alpha.features.programs.editor.enable = true; };
      expected = true;
    };
    testMissingDependency = {
      expr = rejected {
        users = enabledUsers;
        requirements = [ "tools.missing" ];
      };
      expected = true;
    };
    testRootFileIsNotCategory = {
      expr = rejected {
        users = enabledUsers;
        requirements = [ "notes.peer" ];
      };
      expected = true;
    };
    testAbsentCategoryIsNotHardcoded = {
      expr = rejected {
        users = enabledUsers;
        requirements = [ "services.peer" ];
      };
      expected = true;
    };
    testEmptyRequirement = {
      expr = rejected {
        users = enabledUsers;
        requirements = [ "" ];
      };
      expected = true;
    };
    testEmptyQualifiedName = {
      expr = rejected {
        users = enabledUsers;
        requirements = [ "tools." ];
      };
      expected = true;
    };
    testTooManySegments = {
      expr = rejected {
        users = enabledUsers;
        requirements = [ "tools.peer.extra" ];
      };
      expected = true;
    };
    testMetadataMustBeListEvenWhenDisabled = {
      expr = rejected { requirements = "tools.peer"; };
      expected = true;
    };
    testMetadataElementsMustBeStrings = {
      expr = rejected { requirements = [ 42 ]; };
      expected = true;
    };
    testDisabledBundleDoesNotEnforceDependencies = {
      expr = output {
        requirements = [ "tools.missing" ];
        users.alice.hosts.alpha.features.tools.peer.enable = true;
      };
      expected.alpha = {
        events = [ "peer" ];
        homes.alice = [ "peer" ];
      };
    };
    testEmptyRequirements = {
      expr = output {
        requirements = [ ];
        users.alice.hosts.alpha.features.programs.editor.enable = true;
      };
      expected.alpha = {
        events = [
          "editor"
          "editor-extra"
        ];
        homes.alice = [
          "editor"
          "editor-extra"
        ];
      };
    };
    testSharedFlagsReachHostAndUser = {
      expr = output {
        shared.features.tools.peer.enable = true;
        users.alice.hosts.alpha.features.programs.editor.enable = true;
      };
      expected.alpha = enabledAlpha;
    };
    testUserHomeConfigurationIsIsolated = {
      expr = output {
        users = enabledUsers // {
          bob.hosts.alpha.features.tools.peer.enable = true;
        };
      };
      expected.alpha = enabledAlpha // {
        homes = {
          alice = [
            "editor"
            "editor-extra"
            "peer"
          ];
          bob = [ "peer" ];
        };
      };
    };
    testOtherUserCannotSatisfyRequirement = {
      expr = rejected {
        users = {
          alice.hosts.alpha.features.programs.editor.enable = true;
          bob.hosts.alpha.features.tools.peer.enable = true;
        };
      };
      expected = true;
    };
    testHostFlagsAreIsolated = {
      expr = output {
        hosts = {
          alpha = {
            system = "x86_64-linux";
            systemPlatform = "test";
          };
          beta = {
            system = "x86_64-linux";
            systemPlatform = "test";
          };
        };
        users.alice.hosts = {
          alpha.features = enabledFlags;
          beta = { };
        };
      };
      expected = {
        alpha = enabledAlpha;
        beta = emptyAlpha;
      };
    };
    testSystemOnlyPlatform = {
      expr = output {
        autoImport = {
          enable = true;
          root = ./fixtures/system-only;
          prefix = [ "features" ];
        };
        homePlatforms = { };
        users = enabledUsers;
      };
      expected.alpha = {
        events = [
          "editor"
          "peer"
        ];
        homes = { };
      };
    };
    testUserRequirementsCheckedWithoutHomePlatform = {
      expr = rejected {
        autoImport = {
          enable = true;
          root = ./fixtures/system-only;
          prefix = [ "features" ];
        };
        homePlatforms = { };
        users = {
          alice.hosts.alpha.features.programs.editor.enable = true;
          bob.hosts.alpha.features.tools.peer.enable = true;
        };
      };
      expected = true;
    };
  };
  failures = lib.runTests tests;
in
if failures == [ ] then
  { passed = builtins.length (builtins.attrNames tests); }
else
  throw "bundlix tests failed: ${builtins.toJSON failures}"
