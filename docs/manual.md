# LuaBundler User Manual

- "Packages" and "Modules"
- How LuaBundler Works
- Writing a Recipe
  - Creating a Recipe
  - A Recipe for a Program
    - The Entry Point Module
  - Including Packages
    - Standard Libraries
- Resolving Packages
  - Packages Resovling
    - Prefiexed Paths
  - Dynamic Linking
- Bundling Program
  - Automatic Bundling
  - Semi-automatic Bundling
  - Dynamic Linking
- Hacking LuaBundler
  - Code Guide
  - Working with C Source

## "Packages" and "Modules"

"Package" and "modules" share similar meaning and are used frequently in this document. Saying "package", we mean the piece of the bundle. The "module" is used when describing Lua modules, whether for C modules or for Lua modules.

## How LuaBundler Works

Read from recipe, LuaBundler will bundle all lua source files into a `.c` source file. For Lua C modules, LuaBundler only refer the "open functions" in the generated source file.

You can compile the file and link libraries (include Lua C modules) to one executable.

At the executable starts up, LuaBundler will create a new Lua interpreter and inject a "bundle searcher" into package seachers. The bundle searcher is placed right after the preload searcher. (For the mechanism of `require()`, see https://www.lua.org/manual/5.4/manual.html#pdf-require)

## Writing a Recipe

LuaBundler works around lua files called "recipes". They are regular Lua modules which returns a table can be read by LuaBundler.

> Security Warning: Read the untrusted recipe before running it. LuaBundler tries its best, but there is not guarantee that it will run in an isolated environment. The recipe might cook your computer without caution.

### Creating a recipe

A recipe is just a regular Lua module:

````lua
-- recipe.lua
return {
  rev = 0,
}
````

You must specify field `rev`, it indicate the using recipe definition. Current LuaBundler uses `0`.

### A Recipe for a Program

You must specifiy two fields if you want to bundle an executable: `output` and `entry_point`.

````lua
-- recipe.lua
return {
  rev = 0,
  output = "program",
  entry_point = "myprogram.entrypoint",
  included = {
    myprogram = {"entrypoint"}
  }
}
````

`output = "program"` tells LuaBundler you want to build an executable, `entry_point` specify the entry point module.

#### The Entry Point Module

The entry point module is a module return a function. The function will be run as the entry point of the program. Just like below:

````lua
-- myprogram/entrypoint.lua
return function(...)
  print("Hello World!", ...)
end
````

The command arguments given by system will be passed as the arguments of the function. Regularly, the first argument is the program name.

The mechainism is different from the standalone Lua, here is a sample script to use the entry point with the standalone:

````lua
-- myprogram/init.lua
local entry_point = require "myprogram.entrypoint"

entry_point(table.unpack(arg, 0))
````

The entry point module is not automatically included in bundle, don't forget to include it (We will explain the `included` later).

### Including Packages

The `included` field is to specify the bundled packages.

````lua
-- recipe.lua
return {
  rev = 0,
  output = "program",
  entry_point = "myprogram.entrypoint",
  included = {
    myprogram = {"entrypoint", "utils"},
    "argparse",
  }
}
````

Setting the map with an table, the key will be the parent package, the value will be interpreted as the sub package. For example:

````lua
myprogram = {"entrypoint", "utils"}
````

is same as
````lua
"myporgram.entrypoint",
"myprogram.utils",
````

If you want to refer the parent package itself, use an empty string: `""`.

````lua
myprogram = {"", "myprogram.utils"} -- same as "myprogram", "myprogram.utils"
````

#### Standard Libraries

`lua` package and its sub packages are handled differently in LuaBundler. `lua` package indicate the Lua interpreter and is always included. Besides, `base` and `package` standard library is also automatically included. The rest standard libraries will be bundled if you specified:

- `table`
- `utf8`
- `string`
- `os`
- `math`
- `io`
- `debug`
- `coroutine`

They are represented as sub packages under `lua`. To use them, just include them like other packages:

````lua
-- recipe.lua
return {
  rev = 0,
  output = "program",
  entry_point = "myprogram.entrypoint",
  included = {
    myprogram = {"entrypoint", "utils"},
    lua = {"table", "math", "string", "io"},
    "argparse",
  }
}
````

Unlike regular modules, they will also being set as global variables. Above example will set global varables `table`, `math`, `string`, `io` to the associating module. (Just like the standalone Lua!)

If you want to include all standard libraries, use "lua.*":

````lua
-- recipe.lua
return {
  rev = 0,
  output = "program",
  entry_point = "myprogram.entrypoint",
  included = {
    myprogram = {"entrypoint", "utils"},
    lua = {"*"},
    "argparse",
  }
}
````

## Resolving Packages

LuaBundler may search for three types of files:

- Lua source files (`.lua`)
- Lua C modules
- Lua C module archive objects (`.a` and `.o`)

Unless specified `--dynlink` to allow dynamic linking, LuaBundler won't search for Lua C modules.

You can use `luabundler resolved-paks` to check the packages. Here is an example from LuaBundler (We will explain the `--prefix` later):
````
$ luabundler resolved-paks bundle-recipe.lua --prefix lua_modules/
FileType Kind   Name                     Path                                  
──────── ────── ──────────────────────── ──────────────────────────────────────
         src    argparse                 lua_modules/share/lua/5.4/argparse.lua
         src    tprint                   lua_modules/share/lua/5.4/tprint.lua  
archive  native stringy                  lua_modules/lib/lua/5.4/stringy.o     
         src    luabundler.cli           ./luabundler/cli.lua                  
         src    luabundler.template_prog ./luabundler/template_prog.lua        
         src    luabundler.searchers     ./luabundler/searchers.lua            
         src    luabundler.bundler       ./luabundler/bundler.lua              
         src    luabundler.cookbook      ./luabundler/cookbook.lua             
         src    luabundler.utils         ./luabundler/utils.lua                
         src    luabundler.pathlib       ./luabundler/pathlib.lua              
         std    *                                                              
archive  native lua                      lua_modules/lib/liblua.a
````

Packages have three kinds:
- native (native modules or module archive objects)
- src (source file)
- std (standard library)

For "native" kind, there are two file types:
- archive (module archive objects)
- dyn (dynmaic library, regular C module)

Without `--dynlink` option, LuaBundler will not look for regular Lua C module.

## Package Resolving

Without any options, LuaBundler uses `package.path` and `package.cpath` to search Lua source files and Lua C modules. You should avoid it since the values are defined by the host Lua standard library. 

Unless `--prefix` is defined, LuaBundler will not search for Lua C module archive objects.

### Prefixed Paths

When `--prefix` is defined, LuaBundler will use the prefixed paths to search modules. Here is the search order:

- Lua files

  1. `./?.lua`
  2. `./?/init.lua`
  3. `<prefix>/share/lua/<lua-version>/?.lua`
  4. `<prefix>/share/lua/<lua-version>/?/init.lua`

- Archive objects

  5. `./?.a`
  6. `./?.o`
  7. `<prefix>/lib/lua/<lua-version>/?.a`
  8. `<prefix>/lib/lua/<lua-version>/?.o`
  9. `<prefix>/lib/lib?.a`
  10. `<prefix>/lib/?.a`
  11. `<prefix>/lib/lib?.o`
  12. `<prefix>/lib/?.o`

- C modules (only when dynamic linking is allowed)

  13. `./?.<native-file-ext>`
  14. `<prefix>/lib/lua/<lua-version>/?.<native-file-ext>`

### Dynamic Linking

LuaBundler can help dynamic linking by passing `--dynlink` to subcommands. You should pay attention to your linking libraries or the product may not work. For example, if your Lua compiled with dynamic library support, you may want to link `dl` for your bundle.

Another library you must pay attention is the `math` standard library. It requires the `m` from C standard library. Of cause, don't forget the standard library itself. Some C standard library implementation, like musl, already bundle `dl` `m` into the `c` standard library, so it's not required to specify the two.

If you are cross building bundle, consider a C compiler with bundled libc. The builtin clang from [Zig](https://ziglang.org) is a good choice. Things like that can ease the hurt to deal with libc (they did heavy lifting dealing with the OS).

You can also dynamic link some libraries while statically bundle the others. You are on control.

## Bundling Program

Before bundling, you need to check if all your package can be found by LuaBundler (and all required packages are in the recipe).

LuaBundler supports two ways for bundling:

- Automatic 
- Semi-Automatic (Recommended)

Since the automatic way is not so stable (like, it depends on if your compiler can receive source code from standard input), we recommend the alternative.

### Automatic Bundling

You can use `luabundler make <recipe>` to bundle automatically. It will bundle the files and calls the compiler to compile and link. For the latter, you must give the compiler command by `CC` envionment variable or `--cc` option.

You can specify the output file name by `-o`

````
$ CC=clang luabundler make recipe.lua --prefix=lua_modules -o test
clang -Ilua_modules/include lua_modules/lib/liblua.a -o test -
````

### Semi-automatic bundling

Semi-auto bundling includes two steps:

1. bundle the files into one C source file
2. compile the source file

To bundle the files, use `luabundler bundle <recipe>`, with `-o` option to specify the output name:

````
luabundler bundle recipe.lua --prefix=lua_modules -o myprogram.c
````

You can use the `luabundler ccflags <recipe>` to get the flags for the compiler.

````
$ luabundler ccflags recipe.lua --prefix=lua_modules -o myprogram
-Ilua_modules/include lua_modules/lib/liblua.a -o myprogram
````

In action, you can combine with `xargs`:

````
$ luabundler ccflags recipe.lua --prefix=lua_modules -o myprogram | xargs zig cc -target x86_64-linux-musl -O3 -Wall -g
````

## Hacking LuaBundler
(To Be Done...)
