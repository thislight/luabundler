# Bootstrapping LuaBundler

You can bundle luabundler using luabundler. This article describes how to bundle luabundler with or without bundled luabundler executable. By saying "bundled" executable, we mean a executable statically including all its requirements to run on a operating sytstem, including libc.

This article sets the target platform as Linux on x86_64. The procedure is similar for other platforms.

## Requirements

We are building the bundle on a Linux machine.

- [Zig compiler](https://ziglang.org/download/) 0.9+, the built-in C/C++ compiler works like magic!
- [Lua](https://lua.org) 5.4
- [luarocks](https://luarocks.org) latest

## Which bundler you can use

LuaBundler is just a regular program and can be run without bundling. Saying that, you can simply run `luabundler/init.lua` by a standalone Lua executable (with corrected dependencies). You don't need another executable or package to bundle your own LuaBundler executable.

Of cause, you can still use a bundled LuaBundler.

## Download Lua 5.4 source

We need an archive object to bundle Lua. Most distro does not provide the static archive, we must do it ourselves.

Download the source here: https://www.lua.org/download.html

Exact to `native_deps/lua` under the project root, just a recommendation. The `native_deps` is already added to `.gitignore`.

The makefile of Lua using `gcc` by default. You can modifiy it to `zig cc` or something, and it's fine to ignore it if you are not doing corss compiling.

````sh
# In native_deps/lua/
make && make local
````

The production will be placed at `install`. Assume your source is at `native_deps/lua`, the production will be at `native_deps/lua/install`. We need to copy `include` and `lib` to `lua_modules`

````sh
mkdir -p lua_modules/include lua_modules/lib # Create the directories
cp -a native_deps/lua/install/include/ lua_modules/include/
cp -a native_deps/lua/install/lib/ lua_modules/lib/
````

Note: the `lua_modules` directory is also used by luarocks. Just copy the files if it's exists.

## Build stringy

luabundler uses stringy, we must build an archive to bundle it.

Download the source here: http://github.com/mdeneen/lua-stringy

We wll exact to `native_deps/stringy`.

Just build the `stringy.o`:

````sh
# In native_deps/stringy
make stringy.o
````

For a lua C library, we place it to `lua_modules/lib/lua/<lua version>/`

````
cp stringy.o lua_modules/lib/lua/5.4/
````


## Install dependencies to run luabundler

Use luarocks to install dependencies and the luabundler code.

````
luarocks build
````

To use depdencies from `lua_modules`, we must apply `LUA_PATH` and `LUA_CPATH` changes:

````
eval `luarocks path`
````

## See if all packages can be resolved

Use `<luabundler> resolved-paks bundle-recipe.lua --prefix ./lua_modules/` to see if all packages can be resolved by luabundler.

````
# In project root
$ lua luabundler/init.lua resolved-paks bundle-recipe.lua --prefix ./lua_modules/
FileType Kind   Name                     Path                                    
──────── ────── ──────────────────────── ────────────────────────────────────────
         src    argparse                 ./lua_modules/share/lua/5.4/argparse.lua
         src    tprint                   ./lua_modules/share/lua/5.4/tprint.lua  
archive  native stringy                  ./lua_modules/lib/lua/5.4/stringy.o     
         src    luabundler.cli           ./luabundler/cli.lua                    
         src    luabundler.template_prog ./luabundler/template_prog.lua          
         src    luabundler.searchers     ./luabundler/searchers.lua              
         src    luabundler.bundler       ./luabundler/bundler.lua                
         src    luabundler.cookbook      ./luabundler/cookbook.lua               
         src    luabundler.utils         ./luabundler/utils.lua                  
         src    luabundler.pathlib       ./luabundler/pathlib.lua                
         std    *                                                                
archive  native lua                      ./lua_modules/lib/liblua.a              
````

## Run bootstrap script

Run bootstrap bundling script to bundle luabundler. The first argument is the luabundler, the second is the output executable name, the third is the compiler.

````
./scripts/bootstrap.sh "lua luabundler/init.lua" luabundler-x86_64-linux "zig cc"
````
