{
  inputs = {
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
  }:
    utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          config = {};
          overlays = [self.overlays.neovim];
          inherit system;
        };
      in {
        packages = rec {
          neovim-unwrapped = pkgs.neovim-unwrapped;
          neovim = pkgs.neovim;
          default = neovim;
        };
      }
    )
    // {
      overlays = rec {
        default = neovim;
        neovim = final: prev: let
          inherit (final) lib;
        in {
          neovim-unwrapped = let
            # Convert neovim's deps.txt to attrset of sources
            deps = lib.pipe ./cmake.deps/deps.txt [
              builtins.readFile
              (lib.splitString "\n")
              (map (builtins.match "([[:alnum:]_]+)_(URL|SHA256)[[:blank:]]+([^[:blank:]]+)[[:blank:]]*"))
              (lib.remove null)
              (builtins.foldl' (acc: elem: let
                name = lib.toLower (builtins.elemAt elem 0);
                key = lib.toLower (builtins.elemAt elem 1);
                value = builtins.elemAt elem 2;
              in
                lib.recursiveUpdate acc {${name}.${key} = value;}) {})
              (builtins.mapAttrs (_: attrs: final.fetchurl attrs))
            ];

            # Get src version, 9 characters from commit hash, or filename without 'v' prefix
            versionFromSrc = src:
              lib.pipe src.name [
                # Remove .tar.* extension
                (lib.splitString ".tar.")
                builtins.head
                builtins.parseDrvName
                (parsed:
                  if parsed.version != ""
                  then parsed.version
                  else lib.removePrefix "v" parsed.name)
                (name:
                  if builtins.stringLength name == 40
                  then builtins.substring 0 9 name
                  else name)
              ];

            # Remove original and append overriden derivation to a list
            replaceInput = prev: drv: builtins.filter (x: lib.getName x != lib.getName drv) prev ++ [drv];

            # Neovim input overrides
            overrides = rec {
              # LuaJIT
              lua = let
                # luv
                packageOverrides = finalLua: prevLua: let
                  # Update version in rockspec file
                  rockspecUpdateVersion = orig: name: version: let
                    # Revision is required after version
                    v =
                      if lib.hasInfix "-" version
                      then version
                      else "${version}-1";
                  in
                    final.runCommand "${name}-${v}.rockspec" {} ''
                      sed -E "s/(version[[:blank:]]*=[[:blank:]]*[\"'])(.*)([\"'])/\1${v}\3/" ${orig} >$out
                    '';
                in {
                  luv =
                    (prevLua.luaLib.overrideLuarocks prevLua.luv rec {
                      version = versionFromSrc deps.luv;
                      src = deps.luv;
                      # Update version in rockspec file
                      knownRockspec = rockspecUpdateVersion prevLua.luv.knownRockspec "luv" version;
                    })
                    .overrideAttrs (prevAttrs: {
                      buildInputs = replaceInput prevAttrs.buildInputs libuv;
                    });
                  libluv = prevLua.libluv.overrideAttrs (prevAttrs: {
                    inherit (finalLua.luv) version src;
                    buildInputs = replaceInput prevAttrs.buildInputs libuv;
                  });
                  lpeg = prevLua.luaLib.overrideLuarocks prevLua.lpeg rec {
                    version = versionFromSrc deps.lpeg;
                    src = deps.lpeg;
                    knownRockspec = rockspecUpdateVersion prevLua.lpeg.knownRockspec "lpeg" version;
                  };
                };
              in
                prev.luajit.override (prevArgs: {
                  version = "2.1+" + versionFromSrc deps.luajit;
                  src = deps.luajit;
                  self = lua;
                  inherit packageOverrides;

                  # Fix luarocks_bootstrap building
                  # Lua interpreters have passthru.luaOnBuild attribute
                  # referring to the overriden version from pkgsBuildHost.
                  # Due to a possible bug in nixpkgs src attribute isn't overriden, see file
                  #   pkgs/development/interpreters/luajit/default.nix
                  # When overriding lua all derivation parameters are skipped with
                  #   inputs' = lib.filterAttrs (n: v: ! lib.isDerivation v && n != "passthruFun") inputs;
                  # And src is a derivation, thus it's skipped. Override src manually to fix.
                  pkgsBuildHost =
                    prevArgs.pkgsBuildHost
                    // {
                      ${lua.luaAttr} = prevArgs.pkgsBuildHost.${lua.luaAttr}.override {src = deps.luajit;};
                    };
                });

              # Tree-sitter
              tree-sitter = prev.tree-sitter.overrideAttrs (prev: rec {
                version = versionFromSrc deps.treesitter;
                src = deps.treesitter;
                # Need to update cargo hash every time
                cargoHash = "sha256-44FIO0kPso6NxjLwmggsheILba3r9GEhDld2ddt601g=";
                cargoDeps = prev.cargoDeps.overrideAttrs {
                  name = "${prev.pname}-${version}-vendor.tar.gz";
                  inherit src;
                  hash = cargoHash;
                  outputHash = cargoHash;
                };
              });

              # libuv
              libuv = prev.libuv.overrideAttrs {
                version = versionFromSrc deps.libuv;
                src = deps.libuv;
              };

              # Unibilium
              unibilium = prev.unibilium.overrideAttrs (prev: {
                version = versionFromSrc deps.unibilium;
                src = deps.unibilium;
                # autoreconf is needed for newer versions to generate Makefile
                nativeBuildInputs = lib.unique (prev.nativeBuildInputs ++ [final.autoreconfHook]);
              });

              # libvterm neovim fork
              libvterm-neovim = prev.libvterm-neovim.overrideAttrs {
                version = versionFromSrc deps.libvterm;
                src = deps.libvterm;
              };
            };

            # Tree-sitter parsers
            treesitter-parsers = lib.pipe deps [
              (lib.filterAttrs (key: _: lib.hasPrefix "treesitter_" key))
              (lib.mapAttrs' (name: src:
                lib.nameValuePair (lib.removePrefix "treesitter_" name) {
                  language = name;
                  version = versionFromSrc src;
                  src = src;
                }))
              (x:
                x
                // {
                  markdown = x.markdown // {location = "tree-sitter-markdown";};
                  markdown_inline =
                    x.markdown
                    // {
                      language = "markdown_inline";
                      location = "tree-sitter-markdown-inline";
                    };
                })
              (builtins.mapAttrs (_: attrs: overrides.tree-sitter.buildGrammar attrs))
            ];
          in
            (prev.neovim-unwrapped.override overrides)
            .overrideAttrs (prevAttrs: let
              cmakeLists = builtins.readFile ./CMakeLists.txt;
              getValue = name: builtins.head (builtins.match ''.*\(${name} "?([^)"]*)"?\).*'' cmakeLists);
              major = getValue "NVIM_VERSION_MAJOR";
              minor = getValue "NVIM_VERSION_MINOR";
              patch = getValue "NVIM_VERSION_PATCH";
              prerelease = let
                srcPrerelease = getValue "NVIM_VERSION_PRERELEASE";
              in
                lib.optionalString (srcPrerelease != "") (srcPrerelease
                  + lib.optionalString (self ? shortRev) "+${self.shortRev}"
                  + lib.optionalString (self ? dirtyShortRev) "+${self.dirtyShortRev}");
            in {
              version = "${major}.${minor}.${patch}${prerelease}";
              src = ./.;

              postPatch = ''
                ${prevAttrs.postPatch}
                sed -i '/NVIM_VERSION_PRERELEASE/s/".*"/"${prerelease}"/' CMakeLists.txt
              '';

              # Tree-sitter parsers inherit neovim version in the default builder
              # To avoid rebuilding parsers every time neovim version is changed
              # use my own parsers inheriting version from deps.txt
              treesitter-parsers = {};
              postInstall = ''
                ${prevAttrs.postInstall}
                ${lib.concatStrings (lib.mapAttrsToList (language: grammar: ''
                    ln -s ${grammar}/parser $out/lib/nvim/parser/${language}.so
                  '')
                  treesitter-parsers)}
              '';
            });
        };
      };
    };
}
