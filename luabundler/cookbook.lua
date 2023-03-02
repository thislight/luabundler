-- Copyright The LuaBundler Contributors
-- SPDX: Apache-2.0

local format = string.format
local bundler = require "luabundler.bundler"
local searchers = require "luabundler.searchers"
local utils = require "luabundler.utils"
local pathlib = require "luabundler.pathlib"
local get_os_sep = utils.get_os_sep

local function make_prefixed_searchpath_templates(prefix, lua_version, native_file_ext)
    local lib_dir = pathlib.pure({prefix, "lib"})
    local lua_lib_dir = pathlib.pure({lib_dir, "lua", lua_version})
    local shared_dir = pathlib.pure({prefix, "share", "lua", lua_version})
    local natives = {
        pathlib.pure({".", "?."..native_file_ext}):tostring(),
        lua_lib_dir:child("?."..native_file_ext):tostring(),
        ""
    }
    local srcs = {
        pathlib.pure({".", "?.lua"}):tostring(),
        pathlib.pure({".", "?", "init.lua"}):tostring(),
        shared_dir:child("?.lua"):tostring(),
        shared_dir:child("?", "init.lua"):tostring(),
        "",
    }
    local archives = {
        pathlib.pure({".", "?.a"}):tostring(),
        pathlib.pure({".", "?.o"}):tostring(),
        lua_lib_dir:child("?.a"):tostring(),
        lua_lib_dir:child("?.o"):tostring(),
        lib_dir:child("lib?.a"):tostring(),
        lib_dir:child("?.a"):tostring(),
        lib_dir:child("lib?.o"):tostring(),
        lib_dir:child("?.o"):tostring(),
        ""
    }

    return {
        native = table.concat(natives, ";"),
        src = table.concat(srcs, ";"),
        archive = table.concat(archives, ";"),
    }
end

local function _expand_package_tree(base, tr)
    local result = {}
    for k, v in pairs(tr) do
        local ktype = type(k)
        if ktype == "string" then
            local new_base
            if base then
                new_base = table.concat({base, k}, ".")
            else
                new_base = k
            end
            
            if type(v) == "table" then
                local subtr = _expand_package_tree(new_base, v)
                table.move(subtr, 1, #subtr, #result + 1, result)
            else
                error(format("subtree \"%s\" must use table as value, got %s",
                             new_base, type(v)))
            end
        elseif ktype == "number" then
            if v ~= "" then
                if base then
                    result[#result + 1] = table.concat({base, v}, ".")
                else
                    result[#result + 1] = v
                end
                
            else
                result[#result + 1] = base
            end

        end
    end
    return result
end

local function expaned_package_tree(tr) return _expand_package_tree(nil, tr) end

local function expect_recipe_field(name, value)
    if type(value) == "nil" then
        error(format("recipe: expected field \"%s\"", name))
    end
end

local function table_ihas(t, expected_v)
    for k, v in ipairs(t) do
        if v == expected_v then
            return true
        end
    end
    return false
end

local function resolve_lua(using_searchers, config)
    local allow_dyn_link = config.allow_dyn_link

    if allow_dyn_link then
        return searchers.make_pak("lua", nil, "native", nil, "dynlib")
    else
        for i, s in ipairs(using_searchers) do
            local pak = s("lua")
            if pak then
                if pak.filetype == "archive" then
                    return pak
                else
                    error(format("expect lua library from \"%s\" is object archive file, got %s", pak.path, pak.filetype))
                end
            end
        end
    end
end

local function resolve_packages_recipe0(recipe, config)
    local included_paks_tr = recipe.included
    expect_recipe_field("included", included_paks_tr)
    local allow_dyn_link = config.allow_dyn_link
    local prefix = config.search_prefix
    local native_suffix = config.native_suffix

    local ar_searchpath = nil
    local lua_searchpath = nil
    local dl_searchpath = nil
    
    if prefix then
        local templates = make_prefixed_searchpath_templates(pathlib.pure_natvie(prefix), utils.get_lua_version(), native_suffix or "so")
        ar_searchpath = templates.archive
        lua_searchpath = templates.src
        dl_searchpath = templates.native
    end
    
    local included_paks_names = expaned_package_tree(included_paks_tr)
    local using_seachers = {
        searchers.stdlibs_searcher,
        searchers.make_lua_searcher(lua_searchpath),
    }
    if ar_searchpath then
        using_seachers[#using_seachers + 1] = searchers.make_archive_seacher(ar_searchpath)
    end
    if allow_dyn_link then
        using_seachers[#using_seachers + 1] = searchers.make_native_searcher(dl_searchpath)
    end
    local paks = {}
    local notfound = {}
    for i, name in ipairs(included_paks_names) do
        local pakd = bundler.resolve_package(using_seachers, name)
        if pakd then
            paks[#paks+1] = pakd
        else
            notfound[#notfound+1] = name
        end
    end
    local lua_pak = resolve_lua(using_seachers, config)
    if not lua_pak then
        notfound[#notfound+1] = "lua"
    else
        paks[#paks+1] = lua_pak
    end
    
    return paks, notfound
end

local function resolve_and_group_package_recipe0(recipe, config)
    local native_archive_searchpath = config.native_archive_searchpath

    local paks, notfound = resolve_packages_recipe0(recipe, config)
    if table_ihas(notfound, "lua") then
        error(format("lua is not found (archive search path is %q)", native_archive_searchpath))
    end
    local grps = bundler.group_packages(paks)
    grps.notfound = notfound
    return grps
end



local function render_cc_flags_recipe0(config, paks, output_filename)
    local allow_dyn_link = config.allow_dyn_link
    local include_headers = config.include_headers or {}
    local prefix = config.search_prefix

    local ret = {}
    ret[#ret + 1] = "-std=c11"
    for i, v in ipairs(include_headers) do
        ret[#ret + 1] = format("-I%s", v)
    end
    if prefix then
        ret[#ret + 1] = format("-I%s", pathlib.pure({pathlib.pure_natvie(prefix), "include"}))
    end
    local path_pattern = format("^(.+)%s(.-)$", get_os_sep())
    for i, v in ipairs(paks.natives) do
        if v.filetype == "dynlib" then
            if v.path then
                local parent, name = string.match(v.path, path_pattern)
                ret[#ret + 1] = format("-L%s", parent)
                ret[#ret + 1] = format("-l:%s", name)
            else
                ret[#ret + 1] = format("-l%s", v.name)
            end
        elseif v.filetype == "archive" then
            assert(v.path)
            ret[#ret + 1] = v.path
        else
            error(format("unknown file type \"%s\" for \"%s\"(%s)", v.filetype, v.name, v.path))
        end
    end

    if output_filename then
        ret[#ret + 1] = format("-o%s", output_filename)
    end

    return ret
end

local function bundle_recipe0(recipe, config, paks)
    local output_kind = recipe.output or "program"
    if output_kind ~= "program" then
        error(format("recipe: unsupported output kind %q, supported \"program\"",
                     output_kind))
    end
    local rt_conf = recipe.runtime or {}
    local rt_ex_mod_searchers = rt_conf.external_module_searchers
    
    local entrypoint = recipe.entry_point
    expect_recipe_field("entry_point", entrypoint)

    
    if #paks.notfound > 0 then
        error(format("recipe: packages not found (%s)", table.concat(paks.notfound, ", ")))
    end

    return bundler.bundle_program(paks, entrypoint, {
        rt_external_module_searchers = rt_ex_mod_searchers,
    })
end

local function compile_recipe0(recipe, config, pakgrps, src)
    local cc = config.cc
    if not cc then
        error("config.cc is not set")
    end

    local ccflags = render_cc_flags_recipe0(config, pakgrps, filename)
    table.insert(ccflags, 1, cc)
    table.move({"-xc", "-"}, 1, 2, #ccflags+1, ccflags)
    local ccflags_str = table.concat(ccflags, " ")
    print(ccflags_str)
    local f = io.popen(ccflags_str, "w")
    local stat, err = f:write(bundle_src)
    io.stdout:write(f:read('a') or "")
    if not stat then
        error(format("failed to compile bundle: %s", err))
    end
    local suc, exitreason, ret_code = f:close()
    if ret_code > 0 then
        error(format("cc return code is not zero: %d", ret_code))
    end
end


local function make_recipe0(recipe, config, paks)
    local filename = config.output_filename
    if not filename then
        error("config.output_filename is not set")
    end
    local cc = config.cc
    if not cc then
        error("config.cc is not set")
    end

    local bundle_src = bundle_recipe0(recipe, config, paks)

    compile_recipe0(recipe, config, paks, bundle_src)
end



return {
    expaned_package_tree = expaned_package_tree,
    make_recipe0 = make_recipe0,
    resolve_and_group_package_recipe0 = resolve_and_group_package_recipe0,
    bundle_recipe0 = bundle_recipe0,
    render_cc_flags_recipe0 = render_cc_flags_recipe0,
    resolve_packages_recipe0 = resolve_packages_recipe0,
    compile_recipe0 = compile_recipe0,
}
