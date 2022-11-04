{ config, pkgs, lib, ... }:
with lib;
{

  options = {
    virtualisation = {

      hostForwards = mkOption {
        type = types.listOf (types.submodule {
          options = {
            proto = mkOption {
              type = types.enum [ "tcp" "udp" ];
              description = "Protocol";
            };
            host = mkOption {
              type = types.int;
              description = "Port to forward on the HOST";
            };
            guest = mkOption {
              type = types.int;
              description = "Port to forward to in the guest VM";
            };
          };
        });
        default = [];
        description = "Host forwards for user NIC on VM";
      };

      mounts = mkOption {
        type = types.attrsOf types.path;
        default = {};
        description = "Locations provided as virtfs paths to all VMs";
      };

      drives = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Name of qcow image to create";
            };
            temporary = mkOption {
              type = types.bool;
              description = "Temporary drive; deleted if already exists";
            };
            size = mkOption {
              type = types.ints.positive;
              description = "Disk size in GBs";
            };
          };
        });
        default = [];
        description = "List of virtual drives to create and attach to VM";
      };

    };
  };

}
