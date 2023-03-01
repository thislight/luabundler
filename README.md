LuaBundler bundles your Lua program and its C dependencies into one executable, helps you escape dependency nightmare.

## Why LuaBundler?

- Portable. LuaBundler supports platforms have a C11 compiler and able to run the Lua interpreter. It uses zero magic.
- C dependencies. LuaBundler can help you bundle the C dependencies.
- Dynamic linking is also supported.

## Limitation

- Supported Lua version(s): Lua 5.4
- Versioned C modules are not supported. (the module name have a hyphen, like "a.b.c-v2")

## Getting started

- [User Manual](./docs/manual.md)
- [Bootstraping LuaBundler](./docs/bootstrap.md)

## License

SPDX: Apache-2.0
