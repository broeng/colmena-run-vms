let
  # import our real infrastructure
  hive = import ./hive.nix;
  # combine defaults from hive.nix and hive-test.nix
  mergeDefaults = hiveDefaults: testDefaults:
    hiveDefaults // testDefaults // {
      imports = hiveDefaults.imports ++ testDefaults.imports;
    };
in hive // {

  # provide defaults for all hosts for running a local version
  # of our infrastructure in local VMs
  defaults = { pkgs, lib, nodes, ... }:
    let
      hiveDefaults = hive.defaults {
        inherit pkgs lib nodes;
        # testMode = true;
      };
    in mergeDefaults hiveDefaults {
      # This module will be imported by all hosts
      imports = [
        <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>
        # other test-only imports
        <modules/virtualisation/tmp-rootfs.nix>
        <modules/virtualisation/no-password-sudo.nix>
      ];
    };

  # a node that is only available in local VM runs, and
  # will not be included in any actual colmena deployments.
  test-only-node2 = { name, nodes, ... }: {
    deployment.targetHost = "example.com";
    deployment.tags = [ "nodes" "test" ];

    networking.hostName = name;
    networking.interfaces.eth0.ipv4.addresses = [
      {
        address = "10.11.12.14";
        prefixLength = 24;
      }
    ];
  };

}
