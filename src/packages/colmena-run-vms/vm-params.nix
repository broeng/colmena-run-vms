{ pkgs, lib, nodes, ... }:
with lib;
let

  makeLaunchVMScript = conf:
    let
      generateForwards = fwds: typ:
        concatStringsSep ","
          (map (fwd: "${typ}=${fwd.proto}::${toString fwd.host}-:${toString fwd.guest}") fwds);
      userNIC = hostFwds:
        if hostFwds == [] then
          "-netdev user,id=user.0 -device rtl8139,netdev=user.0"
        else
          "-netdev user,id=user.0,${generateForwards hostFwds "hostfwd"} -device rtl8139,netdev=user.0";
      generateVirtFsMounts = mounts:
        concatStringsSep " \\\n  " (
          mapAttrsToList (k: p:
            "-virtfs local,path=${p},security_model=none,mount_tag=${k}"
          ) mounts);
      generateDrives = drives:
        concatStringsSep " \\\n  " (
          imap0 (idx: d:
            let
              idxs = toString idx;
              driveOpts = "index=${idxs},id=drive${idxs},if=none,file=/tmp/${d.name}.qcow2";
              deviceOpts = "virtio-blk-pci,drive=drive${idxs}";
            in
              "-drive ${driveOpts} -device ${deviceOpts}"
          ) drives);
    in pkgs.writeShellScript "launch-vm" ''
      QEMUBIN=''${QEMUBIN:-${conf.qemuBin}}
      # Build and realise the VM derivation
      BUILTVM=$(${pkgs.nix}/bin/nix-store --realise ${conf.vmDrvPath})
      # Realise the closure information derivation
      CLOSUREINFO=$(${pkgs.nix}/bin/nix-store --realise ${conf.closureInfoDrvPath})
      # Create a directory for storing temporary data of the running VM.
      if [ -z "$TMPDIR" ] || [ -z "$USE_TMPDIR" ]; then
          TMPDIR=$(mktemp -d nix-vm.XXXXXXXXXX --tmpdir)
      fi
      # Create a directory for exchanging data with the VM.
      mkdir -p "$TMPDIR/xchg"
      cd "$TMPDIR"
      NICCONF="-net nic,netdev=user.1,model=virtio -netdev user,id=user.1,$QEMU_NET_OPTS"
      RANDMAC=$(${pkgs.coreutils}/bin/shuf -i 10-99 -n1)
      if [ ! -z "$VDECTL" ]; then
        NICCONF="-net nic,model=virtio,macaddr=fc:ac:14:e8:8f:$RANDMAC,$QEMU_NET_OPTS -net vde,sock=$VDECTL"
      fi
      # Prepare drives
      ${flip concatMapStrings conf.drives (driveConf: ''
         DRIVEPATH=/tmp/${driveConf.name}.qcow2
         ${lib.optionalString driveConf.temporary "rm -rf \"$DRIVEPATH\""}
         if [ ! -f "$DRIVEPATH" ]; then
           qemu-img create -f qcow2 "$DRIVEPATH" "${toString driveConf.size}G"
         fi
      '')}
      # Start QEMU
      exec $QEMUBIN -cpu max \
        -name ${conf.name} \
        -m ${toString conf.memory} \
        -smp ${toString conf.cores} \
        -device virtio-rng-pci \
        $NICCONF \
        -virtfs local,path=/nix/store,security_model=none,mount_tag=nix-store \
        -virtfs local,path="''${SHARED_DIR:-$TMPDIR/xchg}",security_model=none,mount_tag=shared \
        -virtfs local,path="$TMPDIR"/xchg,security_model=none,mount_tag=xchg \
        ${generateVirtFsMounts conf.mounts} \
        ${generateDrives conf.drives} \
        -device virtio-keyboard \
        -usb \
        -device usb-tablet,bus=usb-bus.0 \
        -kernel $BUILTVM/system/kernel \
        -initrd $BUILTVM/system/initrd \
        -append "$(cat $BUILTVM/system/kernel-params) init=$BUILTVM/system/init regInfo=$CLOSUREINFO/registration boot.shell_on_fail console=ttyS0,115200n8 $QEMU_KERNEL_PARAMS" \
        ${userNIC conf.hostForwards} \
        $QEMU_OPTS \
        "$@"
    '';

  # VM configuration
  vmConf =
    mapAttrsToList (key: node:
      {
        name = key;
        tags = node.config.deployment.tags ++ [ "all" ];
        mounts = node.config.virtualisation.mounts;
        launchVM =
          (makeLaunchVMScript {
            vmDrvPath = node.config.system.build.vm.drvPath;
            closureInfoDrvPath = (pkgs.closureInfo {
              rootPaths = [ node.config.system.build.toplevel ];
            }).drvPath;
            qemuBin = "${pkgs.qemu_kvm}/bin/qemu-kvm";
            name = key;
            memory = node.config.virtualisation.memorySize;
            cores = node.config.virtualisation.cores;
            hostForwards = node.config.virtualisation.hostForwards;
            mounts = node.config.virtualisation.mounts;
            drives = node.config.virtualisation.drives;
          }).drvPath;
      }
    ) nodes;

  # combine into an infrastructure configuration
  infraConf = {
    vms = vmConf;
  };
in
  infraConf
