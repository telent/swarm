with import <nixpkgs> {};
(callPackage ./default.nix {}).overrideAttrs(o: rec {
  SWARM_BASE_PATH = "/tmp/services";
  PROJECT_ROOT = builtins.toString ./.;
  LUA_PATH = "${PROJECT_ROOT}/lib/?.lua;${PROJECT_ROOT}/scripts/?.lua";
  nativeBuildInputs = [ pkgs.foreman ] ;
})
