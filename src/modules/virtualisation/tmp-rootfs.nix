{ config, pkgs, lib, ... }:
let
  tmpfs = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=${toString config.virtualisation.diskSize}M"
      "mode=755"
    ];
  };
in
{

  # disable grub
  boot.loader.grub.enable = lib.mkForce false;

  # avoid expectation of a persistent root fs in Qemu VMs
  virtualisation.useDefaultFilesystems = false;

  # configure root to be a tmpfs
  fileSystems."/" = lib.mkForce tmpfs;

  # configure root to be a tmpfs for Qemu VMs
  virtualisation.fileSystems."/" = lib.mkForce tmpfs;

  # disable any swap devices
  swapDevices = lib.mkForce [];

}
