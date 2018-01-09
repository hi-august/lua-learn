--[[
author: liuxiaojie@nicefilm.com
date: 2017-06-12
缓存统计模块
]]
local util = require("core.util")
local json = require("core.json")

local _M = {}

local mt = { __index = _M }

_M.default_stats_instance = nil

-- stats_shm_name 统计的shmdict名称.
-- 统计前缀.
-- 缓存名称.
function _M:new(stats_shm_name, prefix, cache_type)
  if not stats_shm_name or stats_shm_name=="" then
    return nil
  end

  prefix = prefix or ""
  cache_type = cache_type or ""

	local obj = {stats_shm_name=stats_shm_name, prefix=prefix, cache_type=cache_type}

	return setmetatable(obj, mt)
end

function _M.init_default_stats_instance(stats_shm_name)
  if _M.default_stats_instance then
    return
  end

  if not stats_shm_name or stats_shm_name=="" then
    return
  end

  local cachestats = _M:new(stats_shm_name)
  cachestats:flush_all(true)
  
  _M.default_stats_instance = cachestats
end

function _M:stats(key)
	local cache = ngx.shared[self.stats_shm_name]
	
	if self.prefix then
		key = self.prefix .. "|" .. self.cache_type .. "|" .. key
	end
	
	local newval, err
	if cache then
		newval, err = cache:incr(key, 1, 0)
	else
		ngx.log(ngx.ERR, "stats key:", key, " failed! err cache is nil")
		return false, nil
	end
  
  return true, newval
end

function _M:list_stats(prefix, max_count)
	local cache = ngx.shared[self.stats_shm_name]
	
	max_count = max_count or 1024
	
	local keys = cache:get_keys(max_count)
	table.sort(keys)
	
	local stats = {}
	local count = 0
	
	for _, key in ipairs(keys) do
		if prefix == nil or util.startswith(key, prefix) then
			count = cache:get(key)
			
			local item = {key=key, count=count}
			table.insert(stats, item)
		end
	end
	return stats
end

function _M.stats_debug(prefix, max_count)
  ngx.header["Content-Type"] = "text/plain"
  
  local stats_instance = _M.default_stats_instance
  local new_stats = {}
  
  if stats_instance then
    local all_stats = stats_instance:list_stats(prefix, max_count)
  
    
    local stats_entry = ""
    
    for i, stats in ipairs(all_stats) do
      stats_entry = string.format("%02d, %s, %s", i, stats.key, tostring(stats.count))
      table.insert(new_stats, stats_entry)
    end
  end
  
  local stats_list = ""
  if #new_stats > 0 then
    stats_list = table.concat(new_stats, "\n")
  end
  
  ngx.say(stats_list)
end

function _M:list_and_reset_stats(prefix, max_count)
  local cache = ngx.shared[self.stats_shm_name]
  
  max_count = max_count or 1024
  
  local keys = cache:get_keys(max_count)
  table.sort(keys)
  
  local stats = {}
  local count = 0
  
  for _, key in ipairs(keys) do
    if prefix == nil or util.startswith(key, prefix) then
      count = cache:get(key)
      
      local item = {key=key, count=count}
      table.insert(stats, item)
      
      cache:replace(key, 0)
    end
  end
  
  return stats
end

function _M.stats_refresh(prefix, max_count)
  ngx.header["Content-Type"] = "application/json;charset=utf-8"
  
  local stats_instance = _M.default_stats_instance
  local new_stats = {}
  
  if stats_instance then
    local all_stats = stats_instance:list_and_reset_stats(prefix, max_count)
    
    local key = ""
    local count = 0
    local cache_key = ""
    local cache_type = ""
    local sub_key = ""
    
    local key_type = ""
    local map_key_stats = {}
    
    for _, s in ipairs(all_stats) do
      key = s.key
      count = s.count
      
      local keys = util.split(key, "|")
      cache_key = keys[1]
      cache_type = keys[2]
      sub_key = keys[3]
      
      key_type = cache_key .. "|" .. cache_type
      local item = map_key_stats[key_type]
      if not map_key_stats[key_type] then
        item = {cache_key=cache_key, cache_type=cache_type, success=0, fail=0, redis_hit=nil, redis_miss=nil, shm_hit=nil, shm_miss=nil, mix_miss=nil, total=0}
        
        if cache_type == "shm" then
          item.shm_hit = 0
          item.shm_miss = 0
        elseif cache_type == "redis" then
          item.redis_hit = 0
          item.redis_miss = 0
        elseif cache_type == "mix" then
          item.shm_hit = 0
          item.redis_hit = 0
          item.mix_miss = 0
        end
        
        map_key_stats[key_type] = item
        table.insert(new_stats, item)
      end
      
      if sub_key == "true" then
        item.success = count
        item.total = item.total + count
      elseif sub_key == "false" then
        item.fail = count
        item.total = item.total + count
      else
        item[sub_key] = count
      end
    end
  end
  
  local data = {stats=new_stats}
  local resp = json.ok(data)
  local resp_body = json.dumps(resp)
  
  ngx.say(resp_body)
end

-- 清除所有缓存命中计数缓存
function _M:flush_all(force)
  local cache = ngx.shared[self.stats_shm_name]
  
  if not cache then
    return
  end
  
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
