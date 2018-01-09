local json = require("core.json")
local cachestats = require("core.cache.cachestats")
local _M = {}


local mt = { __index = _M }

function _M:new(cfg)
	-- 兼容老代码
	if type(cfg) == 'string' then
		local cachename = cfg
		cfg = {cachename=cachename}
	end

	local stats = nil
	if cfg.stats_shm_name then
		local stats_prefix = cfg.stats_prefix or cfg.cachename
		stats = cachestats:new(cfg.stats_shm_name, stats_prefix, "shm")
	end
    return setmetatable({ cachename = cfg.cachename, stats=stats}, mt)
end

function _M:get_from_cache(key)
    local cache = ngx.shared[self.cachename]
    if cache then
        local str = cache:get(key)
        local obj = str
	    if str then
	        obj = json.tryloads(str)
	    end

	    return obj, str
    else
        ngx.log(ngx.ERR, "get_from_cache(", self.cachename, ")failed! cache is nil")
        return nil
    end
end

-- exptime second.
function _M:set_to_cache(key, value, exptime)
    local cache = ngx.shared[self.cachename]

    if cache then
        local t = type(value)
        if t == 'table' then
        	value._id = nil
            value = json.dumps(value)
        end

        local ok, msg = cache:set(key, value, exptime)
        if not ok then
            ngx.log(ngx.ERR, "set cache(", key, ",", tostring(value), ") failed! err: ", tostring(msg))
        else
            ngx.log(ngx.DEBUG, "set cache(", key,") ok ")
        end
    else
        ngx.log(ngx.ERR, "set_to_cache(", self.cachename, ")failed! cache is nil")
    end
end

function _M:delete_from_cache(cachekey)
	local cache = ngx.shared[self.cachename]
	if cache then
		cache:delete(cachekey)
		ngx.log(ngx.DEBUG, "remove (", cachekey, ") from cache(",self.cachename, ")!")
	else
		ngx.log(ngx.ERR, "remove (", cachekey, ") from cache(",self.cachename, ") failed! cache is nil")
	end

end

--[[
query_func 必须是返回：bool, object 类型的函数。
]]
function _M:cache_query(cachekey, exptime, query_func, ...)
	local cached = "shm_miss"
	local ok, obj = true, nil
    local obj = self:get_from_cache(cachekey)
    if obj ~= nil then
        cached = "shm_hit"
        ok = true
        if type(obj) == "string" and obj == "res-not-found" then
            obj = nil
        end
    else
	    ok, obj = query_func(...)
	    if ok and obj ~= nil then
	       self:set_to_cache(cachekey, obj, exptime)
	    end
	end
	if self.stats then
		local key_cached = cached
		local key_ok = tostring(ok)
		self.stats:stats(key_cached)
		self.stats:stats(key_ok)
	end
    return ok, obj, cached
end

--[[
query_func 必须是返回：bool, object 类型的函数。
emptycache bool 是否缓存空数据
]]
function _M:cache_empty_query(cachekey, exptime, emptycache, query_func, ...)
    local cached = "shm_miss"
    local ok, obj = true, nil
    local obj = self:get_from_cache(cachekey)
    if obj ~= nil then
        cached = "shm_hit"
        ok = true
        if emptycache and type(obj) == "string" and obj == "res-not-found" then
            obj = nil
        end
    else
        ok, obj = query_func(...)
        if emptycache then
            if ok then
                if obj == nil then
                    self:set_to_cache(cachekey, "res-not-found", exptime)
                else
                    self:set_to_cache(cachekey, obj, exptime)
                end
            end
        else
            if ok and obj ~= nil then
                self:set_to_cache(cachekey, obj, exptime)
            end
        end
    end
    if self.stats then
        local key_cached = cached
        local key_ok = tostring(ok)
        self.stats:stats(key_cached)
        self.stats:stats(key_ok)
    end
    return ok, obj, cached
end

-- 清除所有缓存
function _M:flush_all(force)
	local cache = ngx.shared[self.cachename]
	if force then
		local keys = cache:get_keys(10240)
		if keys then
			for _, key in ipairs(keys) do
				cache:delete(key)
			end
		end
	else
		cache:flush_all()
	end
end

return _M
