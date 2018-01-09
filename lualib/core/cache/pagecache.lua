local json = require("core.json")
local util = require("core.util")
local redis = require('resty.redis_iresty')
local cachestats = require("core.cache.cachestats")

local _M = {}

local mt = { __index = _M }
--[[
opts is a table
	unique: 值是否是唯一的.
]]
function _M:new(cfg, page_size, opts)
	local cachename = cfg.cachename or 'redis_' .. tostring(cfg.host)
    local stats = nil
	if cfg.stats_shm_name then
		local stats_prefix = cfg.stats_prefix or cachename
		stats = cachestats:new(cfg.stats_shm_name, stats_prefix)
	end

	local data = opts or {}
	data.page_size=page_size
	data.cfg = cfg
	data.cachename=cachename
	data.stats=stats
	data.timeout = cfg.timeout

    return setmetatable(data, mt)
end

-- 如果key不存在, 返回 true, nil
local function get_last_page(cache, key)
	-- 获取当前页(TODO: 添加缓存)
	local cur_page, err = cache:hget(key, "cur_page")
	if err then
		ngx.log(ngx.ERR, "cache:hget(", key, ",'cur_page') failed! err:", tostring(err))
		return false, err
	end

	return true, cur_page
end

function _M:clean(key)
	local cache = redis:new(self.cfg)
	local ok, err = cache:del(key)
	return ok, err
end

local SCRIPT_ADD = [[
	local key = KEYS[1]
    local value = tonumber(ARGV[1])
    local page_size = tonumber(ARGV[2])
    local cur_page = redis.call('hget', key, 'cur_page')
    if not cur_page then
    	redis.call('hset', key, 'cur_page', 1)
    	cur_page = 1
    end
    local pagekey = tostring(cur_page)
	local str = redis.call('hget', key, pagekey)

    -- decode str
    local vals = nil
    if str then
	    vals = cjson.decode(str)
		assert(type(vals) == 'table', 'decode(' .. str .. ") failed!")
	else
		vals = {d={}, n=2}
	end

	-- 去重逻辑, 相邻的两个元素, 不允许重复.
	if #vals.d > 0 and vals.d[1] == value then
		return 1
	end

	if #vals.d >= page_size then
		local new_page = tostring(redis.call('hincrby', key, 'cur_page', 1))
		local new_node = cjson.encode({p=cur_page,d={value}, n=new_page+1})
		redis.call('hset', key, new_page, new_node)
	else
		table.insert(vals.d, 1, value)
		local valstr = cjson.encode(vals)
		redis.call('hset', key, pagekey, valstr)
	end
	return 1
]]

--[[ 结构定义
-- page_size = 5
redis:
key: RedisHash{
	"cur_page": 3,
	"1": {p=nil, d=[5,4,3,2,1], n=2},
	"2": {p=1, d=[10,9,8,7,6], n=3},
	"3": {p=2, d=[12,11], n=nil},
}
-- cur_page 当前最新的页码.
]]
function _M:add(key, value)
	local cache = redis:new(self.cfg)
	local ok, err = cache:eval(SCRIPT_ADD, 1, key, value, self.page_size)
	return ok == 1, err
end

local SCRIPT_DEL_PAGE = [[ -- line 0
	local key = KEYS[1]
    local page = ARGV[1]
    local pagekey = tostring(page)
    local str = redis.call('hget', key, pagekey)

    -- 当前页数据不存在
    if str == false or str == nil then
    	return 1
    end
    local cur_page = cjson.decode(str)
    if cur_page == nil then
    	error(tostring(key).."[" .. pagekey .. "]'s value is invalid!")
    end

    local cur_page_no = redis.call('hget', key, 'cur_page')
    -- 要删除的是最新的一页, 需要同时修改cur_page值.
    if cur_page_no == page then
    	local pre_page_no = cur_page.p
    	redis.call('hset', key, 'cur_page', pre_page_no)
    end

    if cur_page.n then
    	local pagekey = tostring(cur_page.n)
    	local next_page_str = redis.call('hget', key, pagekey)
    	if next_page_str then
    		local next_page = cjson.decode(next_page_str)
    		if next_page and type(next_page) == 'table' then
    			next_page.p = cur_page.p
		    	redis.call('hset', key, pagekey, cjson.encode(next_page))
    		else
    			error("key:" .. key .. ", pagekey:" .. pagekey .. " cjson.decode(" .. next_page_str .. ") failed!")
    		end
    	end
    end

    if cur_page.p then
    	local pagekey = tostring(cur_page.p)
    	local pre_page_str = redis.call('hget', key, pagekey)
    	if pre_page_str then
    		local pre_page = cjson.decode(pre_page_str)
    		if pre_page and type(pre_page) == 'table' then
    			pre_page.n = cur_page.n
		    	redis.call('hset', key, pagekey, cjson.encode(pre_page))
    		else
    			error("key:" .. key .. ", pagekey:" .. pagekey .. " cjson.decode(" .. next_page_str .. ") failed!")
    		end
    	end
    end
    redis.call('hdel', key, pagekey)
    return 1
]]

function _M:get_page_data(cache, key, page)
	local pagekey = tostring(page)
	local str, err = cache:hget(key, pagekey)
	if err then
        ngx.log(ngx.ERR, "cache:hget(", tostring(key),",", pagekey, ") failed! err:", tostring(err))
        return false, err
    end

    if str == nil then
    	return true, nil
    end

    -- decode str
    local vals, err = json.loads(str)
    if err then
    	ngx.log(ngx.ERR, "json.loads(", tostring(err), ") failed! err:", tostring(err))
    	return false, err
    end
    return true, vals
end

function _M:del_page(key, page)
	local cache = redis:new(self.cfg)
	ngx.log(ngx.INFO, "del page key:", key, ", page:", page)
	local ok, err = cache:eval(SCRIPT_DEL_PAGE, 1, key, page)
	return ok == 1, err
end

local SCRIPT_DEL = [[
	local key = KEYS[1]
    local page = ARGV[1]
    local value = tonumber(ARGV[2])
    local pagekey = tostring(page)
    local str = redis.call('hget', key, pagekey)
    if str == nil then
    	return 1
    end

    -- decode str
    local vals= cjson.decode(str)
    if type(vals) == 'table' and type(vals.d) == 'table' then
    	for i = #vals.d, 1, -1 do
    		if vals.d[i] == value then
    			table.remove(vals.d, i)
    			break
    		end
    	end
    	-- 判断 #vals.d == 0
    	local empty = #vals.d == 0
    	-- redis.log(redis.LOG_WARNING, "vals.d: ", #vals.d, " empty:", tostring(empty))
    	-- 保存
    	local valstr = cjson.encode(vals)

		redis.call('hset', key, pagekey, valstr)
		if empty then
			return 2
		end
		return 1
	else
		error("hget('" .. key .. "," .. pagekey .. ") data:[" .. str .. "] invalid!")
    end
    return 1
]]

-- 删除某一页中的一条记录.
function _M:del(key, page, value)
	local cache = redis:new(self.cfg)
	local ok, err = cache:eval(SCRIPT_DEL, 1, key, page, value)
	if ok == 2 then
		return _M:del_page(key, page)
	end

	return ok == 1, err
end


function _M:list(key, page)
	local cache = redis:new(self.cfg)
	if page == nil then
		local ok = nil
		ok, page = get_last_page(cache, key)
		if not ok then
			return ok, page
		end
		if page == nil then
			return false, "not-exists"
		end
	end

	local pagekey = tostring(page)
	local str, err = cache:hget(key, pagekey)
	if err then
        ngx.log(ngx.ERR, "cache:hget(", tostring(key),",", pagekey, ") failed! err:", tostring(err))
        return false, err
    end

    if str == nil then
    	return false, "not-exists"
    end

    -- decode str
    local vals, err = json.loads(str)
    if err then
    	ngx.log(ngx.ERR, "json.loads(", tostring(err), ") failed! err:", tostring(err))
    	return false, err
    end

	return true, vals
end

return _M
