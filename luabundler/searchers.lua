-- Copyright The LuaBundler Contributors
-- SPDX: Apache-2.0

local function make_pak(name, path, kind, src, filetype)
    return {name = name, path = path, kind = kind, src = src, filetype = filetype}
end

local function make_lua_searcher(paths)
    local paths = paths or package.path
    return function(name)
        local srcpath, errmsg = package.searchpath(name, paths)
        if srcpath then
            local handle = io.open(srcpath, "r")
            local src = handle:read("a")
            handle:close()
            return make_pak(name, srcpath, "src", src)
        else
            return nil, errmsg
        end
    end
end

local function make_native_searcher(paths)
    local paths = paths or package.cpath
    return function(name)
        local libpath, errmsg = package.searchpath(name, paths)
        if libpath then
            return make_pak(name, libpath, "native", nil, "dynlib")
        else
            return nil, errmsg
        end
    end
end

local function make_archive_seacher(paths)
    return function (name)
        local libpath, errmsg = package.searchpath(name, paths)
        if libpath then
            return make_pak(name, libpath, "native", nil, "archive")
        else
            return nil, errmsg
        end
    end
end

local function stdlibs_searcher(name)
    local match = string.match(name, "^lua%.([a-z0-9%*]+)$")
    if match then
        return make_pak(match, nil, "std")
    else
        return nil, "standard library starts with \"lua.\""
    end
end

return {
    make_pak = make_pak,
    make_lua_searcher = make_lua_searcher,
    make_native_searcher = make_native_searcher,
    stdlibs_searcher = stdlibs_searcher,
    make_archive_seacher = make_archive_seacher,
}
