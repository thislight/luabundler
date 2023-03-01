-- Copyright The LuaBundler Contributors
-- SPDX: Apache-2.0

local stringy = require "stringy"
local OS_PATH_SEP = string.match(package.config, "^(.-)\n")

local _P = {}

local function slice(t, i, j)
    local new_t = {}
    table.move(t, i, j, 1, new_t)
    return new_t
end

local function set_path_metatable(p)
    return setmetatable(p, {
        __index = _P,
        __tostring = function(self) return self:tostring() end
    })
end

local function pure(filename_seglist)
    if #filename_seglist > 0 and type(filename_seglist[1]) == "table" then
        local head = filename_seglist[1]:clone()
        if head[#head] == "" then
            table.remove(head, #head)
        end
        local new_t = {}
        table.move(head, 1, #head, 1, new_t)
        table.move(filename_seglist, 2, #filename_seglist, #new_t+1, new_t)
        return set_path_metatable(new_t)
    else
        return set_path_metatable(filename_seglist)
    end
end

local function pure_unix(filename)
    local ret = stringy.split(filename, "/")
    return pure(ret)
end

local function pure_win(filename)
    local ret = stringy.split(filename, "\\")
    return pure(ret)
end

local function pure_natvie(filename)
    local ret = stringy.split(filename, OS_PATH_SEP)
    return pure(ret)
end

function _P:absolutep()
    return #self > 0 and string.match(self[1], "^%.%.?$")
end

function _P:tostring(sep)
    local sep = sep or OS_PATH_SEP
    if self:absolutep() then
        return table.concat(self, sep)
    else
        return table.concat(self, sep)
    end
end

function _P:basename()
    if self[#self] == "" then
        return self[#self - 1]
    else
        return self[#self]
    end
end

function _P:parent()
    if self[#self] == "" then
        return pure(slice(self, 1, #self - 2))
    else
        return pure(slice(self, 1, #self - 1))
    end
end

function _P:clone()
    return pure(table.pack(table.unpack(self)))
end

function _P:child(...) return pure({self, ...}) end

return {
    pure = pure,
    pure_unix = pure_unix,
    pure_win = pure_win,
    pure_natvie = pure_natvie
}
