--
-- User: guoxingjun
-- Date: 2017/9/14
-- Time: 14:28
--
local error = require("core.apierror")
local json = require("core.json")
local util = require("core.util")

local _M = {}

_M.cache_count = nil

function _M.init_uri_count(cache_config)
    if cache_config.cachename then
        _M.cache_count = ngx.shared[cache_config.cachename]
    end
end

-- 统计状态\消耗时间
function _M.count_incr(uri, status, cost)
    if _M.cache_count then
        local start, _ = string.find(uri, "?")
        if start then
            local urls = util.split(uri, "?")
            uri = urls[1]
        end
        uri = string.gsub(uri, "https://", "")
        uri = string.gsub(uri, "http://", "")
        -- 替换https://
        local key = "count|" .. uri .. "|" .. status

        local newval, err = _M.cache_count:incr(key, 1)
        if err ~= nil then
            _M.cache_count:set(key, 1)
        end
        -- 统计消耗时间
        local ckey = "cost|" .. uri
        local newval, err = _M.cache_count:incr(ckey, cost)
        if err ~= nil then
            _M.cache_count:set(ckey, cost)
        end
    end
end

-- 统计消耗时间
function _M.count_cost_incr(uri, cost)
    if _M.cache_count then
        local key = "cost_" .. uri
        _M.cache_count:incr(key, cost)
    end
end

function _M:get_uri_count_list(is_delete)
    local list = {}
    if _M.cache_count then
        local max_count = 5000
        local keys = _M.cache_count:get_keys(max_count)
        for _, key in ipairs(keys) do
            local count = _M.cache_count:get(key)
            local arr_key = util.split(key, "|")
            local pre = arr_key[1]
            local uri = arr_key[2]
            local status = arr_key[3] or nil
            local item = { pre = pre, uri = uri, status = status, count = count }
            table.insert(list, item)
            if is_delete then
                _M.cache_count:delete(key)
            end
        end
    end
    return list
end

return _M