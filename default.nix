{ buildPackages, stdenv ? buildPackages.stdenv }:
let
  luaAttribs =  {
      pname = "lua";
      version = "5.4.0";
      src = builtins.fetchurl {
        url = "https://www.lua.org/ftp/lua-5.4.0.tar.gz";
        sha256 = "0a3ysjgcw41x5r1qiixhrpj2j1izp693dvmpjqd457i1nxp87h7a";
      };
      stripAllList = [ "bin" ];
      postPatch = ''
        sed -i src/Makefile -e "s/^AR= ar/AR= ''$AR/"
        sed -i src/Makefile -e '/^CC=/d' -e '/^RANLIB=/d'
        sed -i src/luaconf.h -e '/LUA_USE_DLOPEN/d' -e '/LUA_USE_READLINE/d'
      '';
      makeFlags = ["linux"
                   "INSTALL_TOP=${placeholder "out"}"
                  ];
    };
    # I don't know why I can't get nixpkgs lua to build without readline
    # but it seems simpler to start from upstream than figure it out
  lua = stdenv.mkDerivation luaAttribs;
  luaBuild = buildPackages.stdenv.mkDerivation luaAttribs;
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
  CFLAGS = "-I${lua}/include";
  LDFLAGS = "-L${lua}/lib";
  depsBuildHost = [lua];
  NATIVE_LUAC = "${luaBuild}/bin/luac";
  postPatch = ''
    test -L ./lib/inspect.lua || ln -s ${inspect_lua} ./lib/inspect.lua
    test -L ./lib/json.lua || ln -s ${json_lua} ./lib/json.lua
  '';

  installFlags = ["DESTDIR=$(out)"];
}
