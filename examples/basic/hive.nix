{
  meta = {
    # Override to pin the Nixpkgs version (recommended). This option
    # accepts one of the following:
    # - A path to a Nixpkgs checkout
    # - The Nixpkgs lambda (e.g., import <nixpkgs>)
    # - An initialized Nixpkgs attribute set
    nixpkgs = <nixpkgs>;

    # You can also override Nixpkgs by node!
    #nodeNixpkgs = {
    #  node-b = ./another-nixos-checkout;
    #};

    # If your Colmena host has nix configured to allow for remote builds
    # (for nix-daemon, your user being included in trusted-users)
    # you can set a machines file that will be passed to the underlying
    # nix-store command during derivation realization as a builders option.
    # For example, if you support multiple orginizations each with their own
    # build machine(s) you can ensure that builds only take place on your
    # local machine and/or the machines specified in this file.
    # machinesFile = ./machines.client-a;
  };

  defaults = { pkgs, lib, nodes, ... }: {
    # This module will be imported by all hosts
    deployment.targetUser = "root";

    imports = [
      <modules/virtualisation/options.nix>
    ];

    # networking
    networking.useDHCP = false;
    networking.usePredictableInterfaceNames = false;
    networking.firewall.allowedTCPPorts = [ 22 ];

    # services
    services.openssh.enable = true;

    # users
    users.users.test = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      initialPassword = "test";
    };
  };

  node1 = { name, nodes, ... }: {
    deployment.targetHost = "example.com";
    deployment.tags = [ "nodes" ];

    networking.hostName = name;
    networking.interfaces.eth0.ipv4.addresses = [
      {
        address = "10.11.12.13";
        prefixLength = 24;
      }
    ];
  };

}
