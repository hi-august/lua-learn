local json = require("core.json")
local redis = require('resty.redis_iresty')
local retry = require("core.retry")
local cachestats = require("core.cache.cachestats")

local _M = {}

local mt = { __index = _M }
--[[
cfg: 主redis配置,
cfg_read: 从redis配置.
]]
function _M:new(cfg, cfg_read)
	if type(cfg_read) ~= 'table' then
    cfg_read = nil
  end
  cfg_read = cfg_read or cfg
  
  local cachename = cfg.cachename or 'redis_' .. tostring(cfg_read.host)
	local stats = nil
	if cfg.stats_shm_name then
		local stats_prefix = cfg.stats_prefix or cachename
		stats = cachestats:new(cfg.stats_shm_name, stats_prefix, "redis")
	end
	
  return setmetatable({ cfg = cfg, cfg_read = cfg_read, cachename=cachename, stats=stats, timeout = cfg.timeout}, mt)
end

-- 如果要使用hash结构进行缓存.key需要为: [key, field]
function _M:get_from_cache(key)
    local cache = redis:new(self.cfg_read)
    local str, err = nil

    if type(key) == 'table' and #key == 2 then
    	local mainkey = key[1]
    	local field = key[2]
    	str, err = cache:hget(mainkey, field)
    	if err then
	        ngx.log(ngx.ERR, "redis:hget(", tostring(mainkey), ",",
	        		tostring(field), ") failed! err:", tostring(err))
	        return nil, err
	    end
    else
	    str, err = cache:get(key)
	    if err then
	        ngx.log(ngx.ERR, "redis:get(", tostring(key), ") failed! err:", tostring(err))
	        return nil, err
	    end
	end
    -- ngx.log(ngx.ERR, "key: ", tostring(key), ", str:", str)
    local obj = str
    if str then
        obj = json.tryloads(str)
        -- 数据已经过期.
        if obj and obj._exptime then 
            if obj._exptime < ngx.time() then 
                return nil
            end
            obj._exptime = nil
        end
    end

    return obj, str
end

-- 如果要使用hash结构进行缓存.key需要为: [key, field]
-- exptime second.
function _M:set_to_cache(key, value, exptime)
    local cache = redis:new(self.cfg)
    local t = type(value)
    exptime = exptime or self.timeout
    if t == 'table' then
        -- if exptime then 
        --     value._exptime = ngx.time() + exptime
        -- end
        value = json.dumps(value)
    end
    if type(key) == 'table' and #key == 2 then
    	local mainkey = key[1]
    	local field = key[2]
    	local ok, err = cache:hset(mainkey, field, value)
    	if not ok then
	        ngx.log(ngx.ERR, "redis:hset(", mainkey, ",", field, ",", tostring(value), ") failed! err: ", tostring(err))
	    	return false, err
	    elseif exptime then 
	    	ok, err = cache:expire(mainkey, exptime)
	    	if not ok then
	    		ngx.log(ngx.ERR, "redis:expire(", mainkey,",", tostring(exptime), ") failed! err: ", tostring(err))
	    	end
	        ngx.log(ngx.DEBUG, "redis:hset(", mainkey, ",", field,") ok ")
	    end
    else
	    local ok, err = cache:setex(key, exptime, value)
	    if not ok then
	        ngx.log(ngx.ERR, "redis:setex(", key, ",", tostring(value), ") failed! err: ", tostring(err))
	    else
	        ngx.log(ngx.DEBUG, "redis:setex(", key,") ok ")
	    end
	end
	return true
end

function _M:delete_from_cache(cachekey)
	local cache = redis:new(self.cfg)
	if type(cachekey) == 'table' then
		local n, err = cache:del(unpack(cachekey))
		if err then
			ngx.log(ngx.ERR, "redis.del(", table.concat(cachekey, ' '), ") failed! err:", tostring(err))
			return false, err
		end
	else
		local n, err = cache:del(cachekey)
		if err then
			ngx.log(ngx.ERR, "redis.del(", cachekey, ") failed! err:", tostring(err))
			return false, err
		end
	end
    -- ngx.log(ngx.DEBUG, "remorediscache.luave (", cachekey, ") from redis!")
    return true
end

function _M:delete_from_cache_all(cachekey)
    if not cachekey then
        return nil, nil
    end

    local cache = redis:new(self.cfg)
    local keys, err = cache:keys(cachekey.."*")
    if keys then
        for _, key in ipairs(keys) do
            local ok, err = cache:del(key)
            ngx.log(ngx.INFO, "remove (", key, ") from redis!" .. "ok=" .. ok)
        end
    end
    return keys, err
end

function _M:sets_add(key, value, exptime)
	local cache = redis:new(self.cfg)
    exptime = exptime or self.timeout
    local ok, err = cache:sadd(key, value)
    if not ok then
        ngx.log(ngx.ERR, string.format("redis:sadd(%s, %s) failed! err: %s", key, tostring(value), tostring(err)))
        return false, err
    elseif exptime then
        ok, err = cache:expire(key, exptime)
        if not ok then
            ngx.log(ngx.ERR, "redis:expire(", key,",", tostring(exptime), ") failed! err: ", tostring(err))
        end
    end
	return true
end

function _M:sets_ismember(key, value)
	local cache = redis:new(self.cfg)
    local res, err = cache:sismember(key, value)
    if not res then
        ngx.log(ngx.ERR, string.format("redis:sismember(%s, %s) failed! err:%s", key, value, tostring(err)))
        return false, err
    end
    return true, res
end

function _M:sets_spop(key)
	local cache = redis:new(self.cfg)
    local res, err = cache:spop(key)
    if not res then
        ngx.log(ngx.ERR, string.format("redis:spop(%s) failed! err:%s", key, tostring(err)))
        return false, err
    end
    return true, res
end

function _M:sets_scard(key)
	local cache = redis:new(self.cfg)
    local res, err = cache:scard(key)
    if not res then
        ngx.log(ngx.ERR, string.format("redis:scard(%s) failed! err:%s", key, tostring(err)))
        return false, err
    end
    return true, res
end

function _M:sets_smembers(key)
	local cache = redis:new(self.cfg)
    local res, err = cache:smembers(key)
    if not res then
        ngx.log(ngx.ERR, string.format("redis:smembers(%s) failed! err:%s", key, tostring(err)))
        return false, err
    end
    return true, res
end

function _M:eval_lua(scripts, ...)
    local cache = redis:new(self.cfg)
    local res, err = cache:eval(scripts, ...)
    if not res then
        ngx.log(ngx.ERR, string.format("redis:eval(%s) failed! err:%s", scripts, tostring(err)))
        return false, err
    end
    return true, res
end
--[[
query_func 必须是返回：bool, object 类型的函数。
]]
function _M:cache_query(cachekey, exptime, query_func, ...)
	local cached = "redis_miss"
	local ok, obj = true, nil
    local obj = self:get_from_cache(cachekey)
    if obj ~= nil then
    	cached = "redis_hit"
    	ok = true
        ngx.log(ngx.DEBUG, "get (", cachekey, ") from redis!")
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

function _M:incr(key)
    local cache = redis:new(self.cfg)
    local res, err = retry.retry(cache.incr, cache, key)
    if err then
      err = "redis:incr(" .. key .. ") failed! err:" .. tostring(err)
      return false, err
    end
    return true, res

end

return _M
