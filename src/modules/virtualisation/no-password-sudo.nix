{ config, pkgs, lib, ... }:
{

  security.sudo.extraRules= [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "ALL" ;
          options= [ "SETENV" "NOPASSWD" ];
        }
      ];
    }
  ];

}
