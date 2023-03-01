#!/bin/sh
# Usage: bootstrap.sh <luabundler> <filename> <cc>
$1 bundle bundle-recipe.lua --prefix ./lua_modules/ -o luabundler.c
$1 ccflags bundle-recipe.lua --prefix ./lua_modules/ -I ./lua_modules/include | xargs $3 -target x86_64-linux-musl -o "$2" -static luabundler.c -O3 -Wall -Werror -g
