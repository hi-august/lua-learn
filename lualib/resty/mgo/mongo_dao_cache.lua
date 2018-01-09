local mongo_dao = require("resty.mgo.mongo_dao")
local shmcache = require("core.cache.shmcache")
local json = require("core.json")
local retry = require("core.retry")
local util = require("core.util")

local _M = {}

local mt = { __index = _M }

--[[
	list_fields, 与detail_fileds分别用于mongodb查询时进行过滤.
	相应的查询函数(与find,find_one, get_by_id, list_by_ids)中的fileds过滤,用于缓存之后的结果再次进行过滤.
	args = {
		list_fields=list_fields,
		detail_fields=detail_fields,
		cachename=cachename,
		cache_prefix=cache_prefix,
		cache_exptime=cache_exptime,
	}
]]
function _M:new(mongo_cfg, collname, id_field, args)
	assert(mongo_cfg ~= nil)
	assert(collname ~= nil)
	assert(id_field ~= nil)
	args = args or {}

	local cachectx = nil
	if args.cachename then
		cachectx = shmcache:new(args)
	end
	local metainfo = args
	metainfo.id_field = id_field
	metainfo.cachectx = cachectx

	local obj = mongo_dao:new(mongo_cfg, collname, metainfo)

	return obj:extends(_M)
end

function _M:super_cache()
	return self.supers[_M]
end

function _M:delete_cache(obj)
	local id_value = obj[self.id_field]
	if id_value and self.cachectx then
		local cachekey = self.cache_prefix .. ':id:' .. tostring(id_value)
		self.cachectx:delete_from_cache(cachekey)
	end
end

-- @overide
function _M:upsert(selector, update, upsert, safe, multi)
	local ok, err = self:super_cache().upsert(self, selector, update, upsert, safe, multi)
    if ok then
    	self:delete_cache(selector)
    end
    return ok, err
end

-- @overide
function _M:delete(selector, singleRemove, safe)
	local ok, err = self:super_cache().delete(self, selector, singleRemove, safe)
	if ok then
    	self:delete_cache(selector)
    end
	return ok, err
end

-- @overide
function _M:find_one(selector, fields)
    local ok, obj = retry.retry(self:super_cache().find_one, self, selector, self.detail_fields)
    if not ok then
        return ok, obj
    end
    if obj == nil then
    	return true, nil
    end
    if obj then
        obj._id = nil
    end
	-- filter allow fields
	if type(obj) == 'table' and fields then
		util.filter_field_white(obj, fields)
	end
	-- obj.__cache = "miss"

    return ok, obj

end

-- @overide
function _M:find(selector, fields, sortby, skip, limit)
	
	local ok, objs = retry.retry(self:super_cache().find, self, selector,fields or self.list_fields, sortby, skip, limit)
    if not ok then
        return ok, objs
    end
	-- filter allow fields
	if type(objs) == 'table' and fields then
		util.list_filter(objs, util.filter_field_white, fields)
	end
    return ok, objs
end

-- 通过id(主键)获取并缓存.
function _M:get_by_id(id, fields, emptycache)
	assert(id ~= nil)
	local selector = {[self.id_field]=id}
	if self.cachectx then
		local cachekey = self.cache_prefix .. ':id:' .. tostring(id)
		-- 这里调用find_one 不要把过滤的fields传进去,传进去,会导致缓存的数据,也是过滤后的,这可能不是我们想要的.
		local ok, obj, cache_status
		if emptycache then
			ok, obj, cache_status = self.cachectx:cache_empty_query(cachekey, self.cache_exptime, emptycache, self.find_one, self, selector)
		else
			ok, obj, cache_status = self.cachectx:cache_query(cachekey, self.cache_exptime, self.find_one, self, selector)
		end
		if ok and obj and type(obj) == 'table' then
			if fields then
				util.filter_field_white(obj, fields)
			end
			obj.__cache = cache_status
		end
		return ok, obj
	end
	return self:find_one(selector, fields)
end

-- 根据id获取一批资源(如果有缓存,优先使用缓存)
function _M:list_by_ids(ids, fields)
	local objs = {}

	-- 优先从缓存中获取数据
	for _, id in ipairs(ids) do
		local ok, obj = self:get_by_id(id, fields)
		if ok and obj then
			if fields then
				util.filter_field_white(obj, fields)
			end
			table.insert(objs, obj)
		elseif not ok then
			return ok, obj
		end
	end

	return true, objs
end

-- 通过id(主键)删除数据(并清除缓存)
function _M:del_by_id(id)
	assert(id ~= nil)
	local selector = {[self.id_field]=id}
	return self:delete(selector, 1, 1)
end

-- 通过id(主键)清除缓存
function _M:del_cache_by_id(id)
    assert(id ~= nil)
    local selector = { [self.id_field] = id }
    return self:delete_cache(selector, 1, 1)
end

-- 清空所有缓存(用于测试)
function _M:flush_all(force)
	if self.cachectx then
		self.cachectx:flush_all(force)
	end
end

local function __FILE__()
    return debug.getinfo(2, "S").short_src
end
_M.src_name = __FILE__()
local hook = require("core.hook")
hook.hook_dao(_M, {new=true, extends=true, init=true, uninit=true})

return _M
