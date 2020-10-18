{ stdenv }:
let
  lua =
    # I don't know why I can't get nixpkgs lua to build without readline
    # but it seems simpler to start from upstream than figure it out
    stdenv.mkDerivation {
      pname = "lua";
      version = "5.4.0";
      src = builtins.fetchurl {
        url = "https://www.lua.org/ftp/lua-5.4.0.tar.gz";
        sha256 = "0a3ysjgcw41x5r1qiixhrpj2j1izp693dvmpjqd457i1nxp87h7a";
      };
      stripAllList = [ "bin" ];
      outputs = [ "out" "bin" "dev" ];

      postPatch = let ar = "${stdenv.hostPlatform.config}-ar"; in ''
#      sed -i src/Makefile -e 's/^AR= ar/AR= ${ar}/'
      sed -i src/luaconf.h -e '/LUA_USE_DLOPEN/d' -e '/LUA_USE_READLINE/d'
    '';
      makeFlags = ["linux"
                   "CC=gcc"
#                   "RANLIB=${stdenv.hostPlatform.config}-ranlib"
                   "INSTALL_TOP=${placeholder "out"}"
                  ];
    };
  inspect_lua = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/kikito/inspect.lua/master/inspect.lua";
    name = "inspect.lua";
    sha256 = "1xk42w7vwnc6k5iiqbzlnnapas4fk879mkj36nws2p2w03nj5508";
  };
  json_lua = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/rxi/json.lua/master/json.lua";
    name = "json.lua";
    sha256 = "0zibpz07spqjwgj05zp0nm11m0l9ymfg89fy6q3k7h5bgyjwvb0f";
  };
in stdenv.mkDerivation {
  name = "swarm";
  src = ./.;
  buildInputs = [lua.out lua.dev];
  postPatch = ''
    echo Woo
    test -L ./lib/inspect.lua || ln -s ${inspect_lua} ./lib/inspect.lua
    test -L ./lib/json.lua || ln -s ${json_lua} ./lib/json.lua
  '';

  installFlags = ["DESTDIR=$(out)"];
}
