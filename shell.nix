let

  # nixpkgs version to use for tools and image builds
  commitRev = "b167f53f9a0a03fdf2874857a28406bf491bc811"; # backport-178531-to-release-22.05
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${commitRev}.tar.gz";
    sha256 = "03jgngckxxv336sgrg2ra20lnlf766hhl09phpp769fqy4dmqgqj";
  };

  # package definitions
  pkgs = import nixpkgs {
    config = {};
  };

  # local package definitions
  colmenaRunVMs = pkgs.callPackage ./src/packages/colmena-run-vms { };

in

pkgs.mkShell {

  buildInputs = [
    colmenaRunVMs
    pkgs.colmena
    pkgs.mdcat
  ];

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs}:$(pwd)/src"
  '';

}
