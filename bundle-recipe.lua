return {
    rev = 0,
    output = "program",
    entry_point = "luabundler.cli",
    included = {
        luabundler = {"cli", "template_prog", "searchers", "bundler", "cookbook", "utils", "pathlib"},
        "argparse",
        "tprint",
        "stringy",
        lua = {"*"}
    },
    runtime = {
        external_module_searchers = false,
    },
}
