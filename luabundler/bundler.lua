-- Copyright The LuaBundler Contributors
-- SPDX: Apache-2.0

local TEMPLATE_PROG = require "luabundler.template_prog"
local format = string.format

-- these replacing should not change the final length of file
local LUA_SRC_ESCAPINGS = {
    {"\\", "\\\\"}, {'"', '\\"'}, {"\n", "\\n"}, {"\t", "\\t"}
}

-- these replacing will change the final length of file
local LUA_SRC_MOD = {{"^#!(.-)\n", "\n"}}

-- Note: base and package is automatically opened.
local LUA_STDLIBS = {
    table = "luaopen_table",
    coroutine = "luaopen_coroutine",
    string = "luaopen_string",
    utf8 = "luaopen_utf8",
    math = "luaopen_table",
    io = "luaopen_io",
    os = "luaopen_os",
    debug = "luaopen_debug"
}

local function escape_lua_src(src)
    for _, t in ipairs(LUA_SRC_MOD) do
        local p, r = table.unpack(t)
        src = string.gsub(src, p, r)
    end
    local len = #src
    for _, t in ipairs(LUA_SRC_ESCAPINGS) do
        local p, r = table.unpack(t)
        src = string.gsub(src, p, r)
    end
    return src, len
end

local function make_src_dvec(escaped_src, src_len)
    return format("((struct lua_bundler_dvec){.data = \"%s\", .len = %d})",
                  escaped_src, src_len)
end

local function make_file_declaration(name, src)
    local escaped_src, src_len = escape_lua_src(src)
    return format(
               '((struct lua_bundler_bundled_pak){.name = "%s", .kind = LUA_BUNDLER_PAK_SRC, .target = (union lua_bundler_bundled_pak_target){.src = %s}, .path = NULL})',
               name, make_src_dvec(escaped_src, src_len))
end

local function make_bundled_pak_name(name) return string.gsub(name, "\n", "_") end

local function make_native_lib_declaration(name)
    return format(
               '((struct lua_bundler_bundled_pak){.name = "%s", .kind = LUA_BUNDLER_PAK_NATIVE, .target = (union lua_bundler_bundled_pak_target){.native_open_fn = &luaopen_%s}, .path = NULL})',
               name, make_bundled_pak_name(name))
end

local function filter_stdlibs(stdlib_decl)
    if stdlib_decl then
        local stdlibs = {}
        for _, v in ipairs(stdlib_decl) do
            if v.name == "*" then
                return {"*"}
            elseif LUA_STDLIBS[v.name] then
                stdlibs[#stdlibs + 1] = v
            else
                error("unknown stdlib \"" .. v .. "\"")
            end
        end
        return stdlibs
    end
    return {}
end

local function bundle_program(resolved_packages, main_package_name, config)
    local config = config or {}
    local enabled_stdlibs = filter_stdlibs(resolved_packages.std or {})

    local function make_decl()
        local src_files = resolved_packages.sources
        local native_libs = {}
        for i, pak in ipairs(resolved_packages.natives) do
            if pak.filetype == "archive" and pak.name ~= "lua" then
                native_libs[#native_libs + 1] = pak
            end
        end
        local total_number_s = tostring(#src_files + #native_libs)
        local decls = {
            "const size_t LUA_BUNDLER_BUNDLED_PAKS_LEN = " .. total_number_s ..
                ";",
            "const struct lua_bundler_bundled_pak LUA_BUNDLER_BUNDLED_PAKS[" ..
                total_number_s .. "] = {"
        }
        for _, pak in ipairs(src_files) do
            decls[#decls + 1] = make_file_declaration(pak.name, pak.src) .. ","
        end
        for _, pak in ipairs(native_libs) do
            decls[#decls + 1] = make_native_lib_declaration(pak.name) .. ","
        end
        decls[#decls + 1] = "};"
        return table.concat(decls, "\n")
    end

    local function make_pre_decls()
        local native_libs = resolved_packages.natives
        local decls = {}
        if #enabled_stdlibs > 0 then
            decls[#decls + 1] = "#include <lualib.h>"
        end
        for _, pak in ipairs(native_libs) do
            if pak.filetype == "archive" and pak.name ~= "lua" then
                decls[#decls + 1] = format(
                                    "LUA_API int luaopen_%s(lua_State *S);",
                                    pak.name)
            end
            
        end
        return table.concat(decls, "\n")
    end

    local function make_config_state()
        local decls = {}
        if #enabled_stdlibs > 0 then
            if enabled_stdlibs[1] == "*" then
                decls[#decls + 1] = "luaL_openlibs(S);"
            else
                for _, v in ipairs(enabled_stdlibs) do
                    decls[#decls + 1] = format(
                                            "luaL_requiref(S, \"%s\", &%s, 1); lua_pop(S, 1);",
                                            v.name, LUA_STDLIBS[v.name])
                end
            end
        end
        if not config.rt_external_module_searchers then
            decls[#decls+1] = "lua_bundler_bundled_disable_external_searchers(S);"
        end
        return table.concat(decls, "\n")
    end

    local bundle_src = string.gsub(TEMPLATE_PROG,
                                   "//%s*!lua%-bundler%-placeholder(%b())",
                                   function(placeholder_wrapped)
        local placeholder = string.sub(placeholder_wrapped, 2,
                                       #placeholder_wrapped - 1)
        if placeholder == "declarations" then
            return make_decl()
        elseif placeholder == "config-state" then
            return make_config_state()
        elseif placeholder == "main-package-name" then
            return main_package_name
        elseif placeholder == "pre-decls" then
            return make_pre_decls()
        else
            error("unknown placeholder: " .. placeholder)
        end
    end)

    return bundle_src
end

local function resolve_package(searchers, name)
    for i, s in ipairs(searchers) do
        local pakd, err = s(name)
        if pakd then return pakd end
    end
    return nil
end

local function group_packages(paks)
    local ret_src = {}
    local ret_native = {}
    local ret_std = {}
    for i, pakd in ipairs(paks) do
        if pakd.kind == "src" then
            ret_src[#ret_src + 1] = pakd
        elseif pakd.kind == "native" then
            ret_native[#ret_native + 1] = pakd
        elseif pakd.kind == "std" then
            ret_std[#ret_std + 1] = pakd
        end
    end
    return {
        sources = ret_src,
        natives = ret_native,
        std = ret_std
    }
end

local function resolve_and_group_packages(searchers, names)
    local ret_notfound = {}
    local paks = {}
    for _, name in ipairs(names) do
        local pakd = resolve_package(searchers, name)
        if pakd then
            paks[#paks+1] = pakd
        else
            ret_notfound[#ret_notfound + 1] = name
        end
    end
    local ret = group_packages(paks)
    ret.notfound = ret_notfound
    return ret
end

return {
    bundle_program = bundle_program,
    resolve_package = resolve_package,
    group_packages = group_packages,
    resolve_and_group_packages = resolve_and_group_packages
}
