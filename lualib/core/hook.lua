--[[
author: liuxiaojie@nicefilm.com
date: 20170111
]]
local _M = {}
local cjson = require("cjson")
local dkjson = require("core.dkjson")

local def_excludes = {
    new=true, extends=true, extends_v2=true
}

local function def_wrapper(name, func)
    return function(...)
        print(string.format("def wrapper before [%s] ....", name))
        local values = { func(...) }
        print(string.format("def wrapper end [%s] ...", name))
        return unpack(values, 1, 10)
    end
end
_M.def_wrapper = def_wrapper

local function fmt_args(...)
    local args = {...}
    local oo_args = {}
    local n = #args
    if n < 10 then
        for i=10,1, -1 do
            if args[i] ~= nil then
                n = i
                break
            end
        end
    end

    for i=2, n do
        if type(args[i]) == 'function' then
            table.insert(oo_args, 'function()')
        else
            table.insert(oo_args, args[i] or "nil")
        end
    end
    return dkjson.encode(oo_args)
end

function _M.dao_log_wrapper(name, func, src_name)
    return function(...)
        local values = { func(...) }
        local ok, err = values[1], values[2]
        if ok == false then
            if err == "ERR.DATA_EXIST" then
                ngx.log(ngx.WARN, tostring(src_name), ": ", name, fmt_args(...), " failed! err: ", tostring(err))
            else
                ngx.log(ngx.ERR, tostring(src_name), ": ", name, fmt_args(...), " failed! err: ", tostring(err))
            end
        end
        return unpack(values, 1, 10)
    end
end

--[[
mod 要hook的模块
excludes: 要排除的方法。
wrapper, 在方法执行前要执行的方法，实现可参考def_wrapper
]]
function _M.hookall(mod, wrapper, excludes)
    if not mod.__hooked then
        excludes = excludes or def_excludes
        wrapper = wrapper or def_wrapper
        for name, func in pairs(mod) do
            if not excludes[name] and type(func) == 'function' then
                mod[name] = wrapper(name, func, mod.src_name)
            end
        end
    end
    mod.__hooked = true
end

local function __FILE__()
    return debug.getinfo(3, "S").short_src
end

function _M.hook_dao(dao_mod, excludes)
    dao_mod.src_name = __FILE__()
    return _M.hookall(dao_mod, _M.dao_log_wrapper, excludes)
end

return _M
