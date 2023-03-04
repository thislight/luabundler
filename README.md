LuaBundler is your escape from the dependency nightmare: it bundles your Lua program and its C dependencies into a single executable.

## Why LuaBundler?

- **Portable.** Requires only the C11 compiler and Lua interpreter.
- **C dependencies.** LuaBundler can help you bundle the C dependencies.
- **Dynamic linking support.** LuaBundler doesn't force you to bundle everything. You can choose what you want to bundle.


## How it works

Reading from your recipe, LuaBundler will bundle all the Lua files into one `.c` source file, referencing the open functions (`luaopen_*`) of the C modules. And LuaBundler can help you compile the file, link (dynamically or statically) the C modules (even the dependencies of the C modules).

You get the executable.

When the executable is started, the LuaBundler runtime creates a new Lua interpreter, injects the bundle module searcher and calls the entry point function. If the code calls `require()` and the module is not imported, `require()` will use the searcher to look for bundled modules. 

## Limitation

- Supported Lua version(s): Lua 5.4
- Versioned C modules are not supported. (which the module name has hyphens, like "a.b.c-v2")

## Getting started

- [User Manual](./docs/manual.md)
- [Bootstraping LuaBundler](./docs/bootstrap.md)

## License

SPDX: Apache-2.0
