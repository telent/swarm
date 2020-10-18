with import <nixpkgs> {};
(callPackage ./default.nix {}).overrideAttrs(o: rec {
  SWARM_BASE_PATH = "/tmp/services";
  PROJECT_ROOT = builtins.getEnv "PWD";
  LUA_PATH = "${PROJECT_ROOT}/lib/?.lua";
  nativeBuildInputs = [ pkgs.foreman ] ;
})
