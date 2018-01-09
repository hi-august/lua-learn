--[[
author: liuxiaojie@nicefilm.com
date: 2017-05-07
shm+redis混合二级缓存
]]
local json = require("core.json")
local util = require("core.util")
local shmcache = require("core.cache.shmcache")
local rediscache = require("core.cache.rediscache")
local cachestats = require("core.cache.cachestats")

local _M = {}

local mt = { __index = _M }

-- 二级缓存，redis的过期时间在new中设置 接口中的exptime只对nginx的shmdict缓存有效
function _M:new(shmcachename, redis_cfg, redis_cfg_read)
	local cfg = util.table_copy(redis_cfg)
	local redis_exptime = cfg.mixcache_exptime or 3600 * 24
	cfg.cachename = cfg.cachename or shmcachename

	local stats = nil
	if cfg.stats_shm_name then
		local stats_prefix = cfg.stats_prefix or cfg.cachename
		stats = cachestats:new(cfg.stats_shm_name, stats_prefix, "mix")
		cfg.stats_shm_name = nil
	end

	local obj = {redis_cfg = cfg, redis_cfg_read=redis_cfg_read, redis_exptime = redis_exptime, stats = stats}
	obj.shm = shmcache:new({cachename=shmcachename})
	obj.redis = rediscache:new(cfg, redis_cfg_read)

	return setmetatable(obj, mt)
end

function _M:get_from_cache(key)
	local cached = nil
	local val, err = self.shm:get_from_cache(key)
	if val == nil then
		val, err = self.redis:get_from_cache(key)
		if val then
			cached = "redis_hit"
		else
			cached = "mix_miss"
		end
	else
		cached = "shm_hit"
	end
	return val, err, cached
end

-- 测试一个key,是否在缓存中.
function _M:cache_test(key)
	local status = {}
	local val, err = self.shm:get_from_cache(key)
	status.shm_hit = val ~= nil
	local val, err = self.redis:get_from_cache(key)
	status.redis_hit = val ~= nil

	return status
end

-- exptime second.
function _M:set_to_cache(key, value, exptime)
	if not exptime then
		exptime = self.redis_exptime
	end
	--	ngx.log(ngx.ERR, "shm:set_to_cache(", key, ",", value, ",", exptime, ")")
	self.shm:set_to_cache(key, value, exptime)
	-- TODO: 修改成异步设置
	self.redis:set_to_cache(key, value, self.redis_exptime)
end

function _M:delete_from_cache(key)
	self.shm:delete_from_cache(key)
	self.redis:delete_from_cache(key)
end

function _M:delete_from_cache_all(cachekey)
 	local keys, err = self.redis:delete_from_cache_all(cachekey)
 	if keys then
 		for _, key in ipairs(keys) do
 			self.shm:delete_from_cache(key)
 		end
 	end
end

--[[
query_func 必须是返回：bool, object 类型的函数。
]]
function _M:cache_query(cachekey, exptime, query_func, ...)
	local ok = true
	local res, str, cached = self:get_from_cache(cachekey)
	if res ~= nil then
		if cached == "redis_hit" then
			-- 回写数据到shmdict中.
			self.shm:set_to_cache(cachekey, str, exptime)
		end
	else
		ok, res = query_func(...)
		if ok and res ~= nil then
		   self:set_to_cache(cachekey, res, exptime)
		end
	end
	if self.stats then
		local key_cached = cached
		local key_ok = tostring(ok)
		self.stats:stats(key_cached)
		self.stats:stats(key_ok)
	end

	return ok, res, cached
end

-- 清除所有缓存
function _M:flush_all(force)

end

return _M
