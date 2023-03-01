-- Copyright The LuaBundler Contributors
-- SPDX: Apache-2.0

local function get_os_sep()
    return string.match(package.config, "^(.-)\n")
end

local function get_lua_version()
    return string.match(_VERSION, "^Lua (.+)$")
end

return {
    get_os_sep = get_os_sep,
    get_lua_version = get_lua_version,
}
