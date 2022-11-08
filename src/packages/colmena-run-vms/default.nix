{ pkgs, lib, ... }:
with lib;
let

  # VDE networking with vde_switch from vde2
  vde2 = rec {

    pid = "/tmp/vdectl.pid";
    vdectl = "/tmp/vdesock.ctl";

    kill = pkgs.writeShellScript "kill-vde" ''
      if [ -f "${pid}" ]; then
        ${pkgs.coreutils}/bin/kill -9 $(cat ${pid}) 2> /dev/null || true
        ${pkgs.coreutils}/bin/rm -rf ${pid}
      fi
    '';

    start = pkgs.writeShellScript "start-vde" ''
      ${kill}
      echo "Starting vde network ..."
      ${pkgs.vde2}/bin/vde_switch -sock ${vdectl} --pidfile ${pid} -dirmode 0700 --hub --daemon
    '';

    stop = pkgs.writeShellScript "stop-vde" ''
      echo "Shutting down vde network ..."
      ${kill}
    '';

    env =
      concatStringsSep " " (
        mapAttrsToList (k: v: "${k}=${v}") {
          VDECTL = vdectl;
        });

  };

  # network configuration to use
  net = vde2;

  tmuxConf = pkgs.writeText "tmux.conf" ''
    set-hook -g session-created 'set remain-on-exit on'
    set-option -g default-shell "${pkgs.bash}/bin/bash"
    bind R run "echo \"stty columns \#{pane_width}; stty rows \#{pane_height}\" | ${pkgs.tmux}/bin/tmux load-buffer - ; ${pkgs.tmux}/bin/tmux paste-buffer"
  '';

  launchVM = pkgs.writeShellScript "run-vm-drv" ''
    VM=''${1}
    if [ ! -f "$VM" ]; then
      echo "ERR: VM derivation does not exist: $VM"
      exit 1
    fi
    # Build and realise the derivation
    BUILTVM=$(${pkgs.nix}/bin/nix-store --realise $VM)
    # Run the VM
    ${net.env} $BUILTVM -nographic
  '';

  launchVMsTMUX = pkgs.writeShellScript "run-vm-drvs" ''
    VMS=$@
    # launch vms in tmux
    TMUX_CMD="new-session -d"
    for vm in $VMS; do
      ${pkgs.tmux}/bin/tmux -f ${tmuxConf} $TMUX_CMD "${launchVM} $vm"
      TMUX_CMD="split-window"
      ${pkgs.tmux}/bin/tmux select-layout tiled
    done
    ${pkgs.tmux}/bin/tmux -f ${tmuxConf} attach
  '';

  colmenaRunVMs = pkgs.writeShellScriptBin "colmena-run-vms" ''
    set -e
    INFRA_ROOT=''${INFRA_ROOT:-.}
    HOST_IP=''${HOST_IP:-10.0.2.2}
    COLMENA_ARGS=''${COLMENA_ARGS:-}
    TAGS=$@
    if [ -z "$TAGS" ]; then
      echo "ERR: You must supply at least one tag on the command line"
      exit 1
    fi
    HIVENIX=$INFRA_ROOT/hive-test.nix
    if [ ! -f "$HIVENIX" ]; then
      echo "$HIVENIX not found. Using $INFRA_ROOT/hive.nix"
      HIVENIX=$INFRA_ROOT/hive.nix
    fi
    export HOST_IP
    INFRA_DESC=$(${pkgs.colmena}/bin/colmena eval -f $HIVENIX ${./vm-params.nix} $COLMENA_ARGS)
    ALL_VMS=""
    for tag in $TAGS; do
      SELECTOR=".vms[] | select(.tags[] | match(\"^$tag\$\")) | .launchVM"
      SELECTED_VMS=$(echo $INFRA_DESC | ${pkgs.jq}/bin/jq --raw-output "$SELECTOR" | tr '\n' ' ')
      ALL_VMS="$ALL_VMS $SELECTED_VMS"
    done
    # Create a directory for storing temporary data of the running VM.
    if [ -z "$TMPDIR" ]; then
      TMPDIR=$(mktemp -d nix-vm.XXXXXXXXXX --tmpdir)
    fi
    # prepare inter-vm networking
    ${net.start}
    # launch all VMs
    ${net.env} TMPDIR=$TMPDIR ${launchVMsTMUX} $ALL_VMS
    # shutdown networking
    ${net.stop}
  '';

in colmenaRunVMs
