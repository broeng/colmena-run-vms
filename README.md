# colmena-run-vms

Scripts and Nix options and configurations for running a colmena infrastructure
definition in a bunch of local virtual machines with QEMU.

## Examples

See ``examples/basic`` for a working example.

Files:

- ``hive.nix``: Your colmena infrastructure definition.
- ``hive-test.nix``: Configuration specific for running your colmena infrastructure in local VMs.

``hive-test.nix`` imports a few nix recipies setting up ``tmpfs`` for root partition, disabling grub,
and configuring no-password sudo access, as an example.

Running:

- Run ``nix-shell`` in the root of this repository.
- Navigate to ``examples/basic``, or export the environment variable ``INFRA_ROOT`` with this path as value.
- Run ``colmena-run-vms all``, which should build and launch the machines.
