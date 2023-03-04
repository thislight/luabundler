# LuaBundler User Manual

- "Packages" and "Modules"
- How LuaBundler Works
- Writing a Recipe
  - Creating a Recipe
  - A Recipe for a Program
    - The Entry Point Module
  - Including Packages
    - Standard Libraries
  - Runtime Options
    - External Module Searchers
- Resolving Packages
  - Packages Resovling
    - Prefixed Paths
  - Dynamic Linking
- Bundling Program
  - Automatic Bundling
  - Semi-automatic Bundling
  - Dynamic Linking
- Hacking LuaBundler
  - Code Guide
  - Working with C Source

## "Packages" and "Modules"

"Package" and "modules" have a similar meaning and are used frequently in this document. When we say "package", we mean the part of the bundle. The "module" is used when describing Lua modules, whether for C modules or for Lua modules.

## How LuaBundler Works

Reading from recipe, LuaBundler bundles all the lua source files into a `.c` source file. For Lua C modules, LuaBundler referencing the "open function" (`luaopen_*`) in the generated source file.

You can compile the file and link libraries (including Lua C modules).

When is the executable started, LuaBundler creates a new Lua interpreter and injects a "bundle searcher" into package searchers. The bundle searcher is placed right after the preload searcher. (For the mechanism of `require()`, see https://www.lua.org/manual/5.4/manual.html#pdf-require)

## Writing a Recipe

LuaBundler works around Lua files called "recipes". These are regular Lua modules that return a table that can be read by LuaBundler.

> **Security warning: Read the untrusted recipe before executing it.** LuaBundler tries its best, but there is not guarantee that it will run in an isolated environment. The recipe may cook your computer if you are not careful.

### Creating a recipe

A recipe is just a regular Lua module:

````lua
-- recipe.lua
return {
  rev = 0,
}
````

You must specify the field `rev`, it indicates the using definition. Current number is `0`.

### A Recipe for a Program

You must specifiy the two fields when bundling an executable: `output` and `entry_point`.

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

The entry point module is a module that returns a function. The function will be run as the entry point of the program. Just like below:

````lua
-- myprogram/entrypoint.lua
return function(...)
  print("Hello World!", ...)
end
````

Started the bundled executable:

````
$ ./myprogram me!
Hello World!    myprogram    me!
````

The command arguments given by system will be passed into the function without modification. For most OS, the first argument is the program name.

The mechainism is different from the standalone Lua, that creates a global table `arg`. Here is a sample script to use the entry point function with the standalone:

````lua
-- myprogram/init.lua
local entry_point = require "myprogram.entrypoint"

entry_point(table.unpack(arg, 0))
````

The unpacking must start from 0, because the program name (first argument) is placed at 0.

The entry point module is not automatically included in bundle. Don't forget to include it in `included` (We will explain the `included` later).

### Including Packages

The `included` field is for describing the bundled packages.

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

Setting the map with a table, the key will be the parent package, the value will be interpreted as the child package. For example:

````lua
myprogram = {"entrypoint", "utils"}
````

is the same as
````lua
"myporgram.entrypoint",
"myprogram.utils",
````

If you want to refer the parent package itself, use an empty string: `""`.

````lua
myprogram = {"", "myprogram.utils"} -- same as "myprogram", "myprogram.utils"
````

#### Standard Libraries

The `lua` package and its child packages are handled differently in LuaBundler.

The `lua` package specifies the Lua interpreter and is always included. The `base` (`_G` and its functions) and `package` (`require` and `package`) standard libraries are also automatically included.

The following libraries are not bundled unless you specify them:

- `table`
- `utf8`
- `string`
- `os`
- `math`
- `io`
- `debug`
- `coroutine`

They are represented as child packages under `lua`. To use them, just include them like normal packages:

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

Unlike regular modules, they will also being set as global variables. The above example sets the global variables `table`, `math`, `string`, `io` to the associated module. (Just like in standalone Lua!)

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

### Runtime Options

You can configure the runtime behaviour using the "runtime" field.

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
  },
  runtime = {},
}
````

#### External Module Searchers

By default, LuaBundler only keeps the preload searcher and the bundle searcher. If you want to keep the original searchers, set `external_module_searchers` to `true`.

````lua
return {
  runtime = {
    external_module_searchers = true,
  }
}
````

The bundle searcher will still be used before the other original searchers, after the preload searcher.

This option does not prevent the program from using external modules: the program can still use external modules, by combining `io.open`, `dostring` and similar functions.

## Resolving Packages

LuaBundler can search for three types of files:

- Lua source files (`.lua`)
- Lua C modules
- Lua C module archive objects (`.a` and `.o`)

Unless you specify `--dynlink` to allow dynamic linking, LuaBundler won't search for Lua C modules.

You can use `luabundler resolved-paks` to check the packages. Here is an example from LuaBundler (we will explain the `--prefix` later):
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

Packages are of three kinds:
- native (native modules or module archive objects)
- src (source file)
- std (standard library)

For the "native" kind, there are two file types:
- archive (module archive objects)
- dyn (dynmaic library, regular C module)

Without the `--dynlink` option, LuaBundler will not look for any regular Lua C module.

## Package Resolving

By default, LuaBundler uses `package.path` and `package.cpath` to search for Lua source files and Lua C modules. This method is not recommended: a) It cannot search for archive objects; and b) controlling these two variables is complex.

You should always specify the `--prefix` option. This will enable prefixed paths.

### Prefixed Paths

When the `--prefix` specified, LuaBundler will use the prefixed paths to search modules. Here is the search order:

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

- C modules (when dynamic linking allowed)

  13. `./?.<native-file-ext>`
  14. `<prefix>/lib/lua/<lua-version>/?.<native-file-ext>`

### Dynamic Linking

LuaBundler can support dynamic linking by passing `--dynlink` to subcommands. You should pay attention to your linking libraries or the product may not work. For example, if your Lua has been compiled with dynamic library support, you may want to link `dl` for your bundle.

Another library you need to aware of is the `math` standard library. It requires the `m` from the C standard library. Of course, don't forget the C standard library itself. Some C standard library implementations, such as musl, already bundle `dl` and `m` into the `c` standard library, so you don't need to specify the both.

If you want to cross-build bundles, consider a C compiler with bundled libc. The built-in clang from [Zig](https://ziglang.org) is a good choice. Things like this can ease the pain of dealing with libc.

You can also dynamically link some libraries and statically bundle the others. You are in control.

## Bundling Program

Before bundling, you need to check that all your packages can be found by LuaBundler (and that all required packages are in the recipe).

LuaBundler supports two ways for bundling:

- Automatic 
- Semi-automatic (Recommended)

Since the automatic way is not as stable (e.g. it depends on whether your compiler can receive source code from standard input), we recommend the alternative.

### Automatic Bundling

You can use `luabundler make <recipe>` for automatic bundling. It will bundle the files and call the compiler to compile and link them. For the latter, you need to pass the compiler command with the `CC` environment variable or the `--cc` option.

You can specify the output filename with `-o`

````
$ CC=clang luabundler make recipe.lua --prefix=lua_modules -o test
clang -Ilua_modules/include lua_modules/lib/liblua.a -o test -
````

### Semi-automatic bundling

Semi-automatic bundling involves two steps:

1. bundle the files into a C source file
2. compile the source file

To bundle the files, use `luabundler bundle <recipe>`, with the `-o` option to specify the output name:

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
