-- Copyright The LuaBundler Contributors
-- SPDX: Apache-2.0

local argparse = require "argparse"
local format = string.format

local function load_recipe_file(filename)
    local fn, err = loadfile(filename, "bt")
    if not fn then
        error(format("failed to load recipe \"%s\": %s", filename, err))
    end
    local stat, recipe = pcall(fn)
    if not stat then
        error(format("failed to load recipe \"%s\": %s", filename, err))
    end
    if not recipe or not recipe.rev then
        error(format(
                  "failed to load recipe \"%s\": looks like not a recipe (falsy value or no 'rev' field, got a %s)",
                  filename, type(recipe)))
    end
    return recipe
end

local function make_config(opts)
    local ret = {}
    ret.allow_dyn_link = opts.dynlink
    ret.output_filename = opts.output
    ret.cc = opts.cc or os.getenv("CC")
    ret.include_headers = opts.system_include
    ret.search_prefix = opts.prefix
    return ret
end

local function print_ccflags(recipe, config)
    local cookbook = require "luabundler.cookbook"
    local paks = cookbook.resolve_and_group_package_recipe0(recipe, config)
    local flags = cookbook.render_cc_flags_recipe0(config, paks,
                                                    config.output_filename)
    print(table.concat(flags, " "))
    return 0
end

local function print_resolved_paks(recipe, config)
    local cookbook = require "luabundler.cookbook"
    local tprint = require "tprint"
    local paks, notfound = cookbook.resolve_packages_recipe0(recipe, config)
    local tab = {}
    for i, name in ipairs(notfound) do
        tab[#tab + 1] = {
            Name = name,
            Kind = "",
            FileType = "",
            Path = "Not Found"
        }
    end
    for i, pakd in ipairs(paks) do
        tab[#tab + 1] = {
            Name = pakd.name,
            Kind = pakd.kind,
            FileType = pakd.filetype,
            Path = pakd.path
        }
    end
    print(tprint(tab))
    return 0
end

local function make(recipe, config)
    local cookbook = require "luabundler.cookbook"
    local paks = cookbook.resolve_and_group_package_recipe0(recipe, config)
    cookbook.make_recipe0(recipe, config, paks)
    return 0
end

local function bundle(recipe, config)
    local cookbook = require "luabundler.cookbook"
    local paks = cookbook.resolve_and_group_package_recipe0(recipe, config)
    local src = cookbook.bundle_recipe0(recipe, config, paks)
    local filename = config.output_filename or "bundle.c"
    local file = io.open(filename, "w+")
    local suc, err = file:write(src)
    if not suc then
        error(format("could not write bunlde to %q: %s", filename, err))
    end
    file:close()
end

return function(...)
    local cmdargs = table.pack(...)
    local progname = table.remove(cmdargs, 1)
    local parser = argparse(progname,
                            "A tool to bundle your lua program and dependencies.")
    parser:command_target("command")

    local command_ccflags = parser:command "ccflags"
                                :summary "Print ccflags used for a recipe."
    command_ccflags:argument "recipe":description("recipe file name")
    command_ccflags:flag "--dynlink":description(
        "Allow dynamic linking. (default: disallow)")
    command_ccflags:option "-o" "--output":description(
        "Set output file name in flags, no content will be written.")
    command_ccflags:option "-I" "--system-include":count "*":description(
        "Add header searching directory")
    command_ccflags:option "--prefix":description("Set library search prefix")

    local command_resolved_paks = parser:command "resolved-paks"
                                      :summary "Print resolving information for bundling packages."
    command_resolved_paks:argument "recipe"
    command_resolved_paks:flag "--dynlink"
    command_resolved_paks:option "--prefix":description(
        "Set library search prefix")

    local command_bundle = parser:command "bundle":summary "Bundle files"
    command_bundle:argument "recipe"
    command_bundle:flag "--dynlink"
    command_bundle:option "-o" "--output":description(
        "File name the bundle writes to. (default: bundle.c)")
    command_bundle:option "--prefix":description("Set library search prefix")

    local command_make = parser:command "make"
                             :summary "Bundle files and compile"
    command_make:argument "recipe"
    command_make:flag "--dynlink":description(
        "Allow dynamic linking. (default: disallow)")
    command_make:option "-o" "--output":description(
        "The final production file name")
    command_make:option "-I" "--system-include":count "*":description(
        "Add header searching directory")
    command_make:option "--cc"
        :description("The command for calling C compiler.")
    command_make:option "--prefix":description("Set library search prefix")

    local ns = parser:parse(cmdargs)
    if ns.command == "ccflags" then
        local recipe = load_recipe_file(ns.recipe)
        local config = make_config(ns)
        return print_ccflags(recipe, config)
    elseif ns.command == "resolved-paks" then
        local recipe = load_recipe_file(ns.recipe)
        local config = make_config(ns)
        return print_resolved_paks(recipe, config)
    elseif ns.command == "make" then
        local recipe = load_recipe_file(ns.recipe)
        local config = make_config(ns)
        return make(recipe, config)
    elseif ns.command == "bundle" then
        local recipe = load_recipe_file(ns.recipe)
        local config = make_config(ns)
        return bundle(recipe, config)
    else
        error("unknown command: " .. ns.command)
    end
    return 127
end
