--[[
author: liuxiaojie@nicefilm.com
date: 20160801
mongol1: https://github.com/aaashun/lua-resty-mongol
mongol2: https://github.com/bigplum/lua-resty-mongol
mongol3: https://github.com/aaashun/lua-resty-mongol
]]
local util = require("core.util")
local mongo = require("resty.mongol")
local json = require("core.json")
local t_ordered = require("resty.mgo.orderedtable")
local _M = {}

local function t_concat(t, seq)
    seq = seq or ""
    if type(t) ~= 'table' then
        return tostring(t)
    end
    if #t > 0 then
        return table.concat(t, seq)
    end
    local keys = {}
    for k, v in pairs(t) do
        table.insert(keys, k .. "_" .. v)
    end
    return table.concat(keys, seq)
end


_M.init_seed = function ()
    local cur_time =  ngx.time()
    math.randomseed(cur_time)
end

function _M.__FILE__()
    return debug.getinfo(2, "S").short_src
end

function _M:extends(child_mod)
    --assert(self.super == nil)
    if self.supers == nil then
    	self.supers = {}
    end
    local super_mt = getmetatable(self)

    -- 当方法在子类中查询不到时，再去父类中去查找。
    setmetatable(child_mod, super_mt)
    -- 这样设置后，子类可以通过self.supers[module].method(self, ...) 调用父类的已被覆盖的方法。
    self.supers[child_mod] = setmetatable({}, super_mt)
    return setmetatable(self, { __index = child_mod })
end

function _M:new(mongo_cfg, collname, metainfo)
	local dbname = mongo_cfg.dbname
	local timeout = mongo_cfg.timeout or 1000*5
    mongo_cfg.timeout = timeout
    collname = collname or "test"

    local ns = dbname .. "." .. collname
    local o = metainfo or {}
    o.mongo_cfg = mongo_cfg
    o.dbname=dbname
    o.collname=collname
    o.ns=ns
    self.__index = self
    setmetatable(o, self)
    return o
end

function _M:init()
    if self.conn then
        return true
    end
	local host = self.mongo_cfg.host
	local port = self.mongo_cfg.port
	local conn = mongo:new()
    conn:set_timeout(self.mongo_cfg.timeout)
    local ok, err = conn:connect(host, port)
    if not ok then
        ngx.log(ngx.ERR, "connect to mongodb (", host, ":", port, ") failed! err:", tostring(err))
        return ok, err
    end

    local db = conn:new_db_handle(self.dbname)
    local username = self.mongo_cfg.username
    local password = self.mongo_cfg.password
    if username and password then
        ok, err = db:auth(username, password)
        if not ok then
            local pool_timeout = self.mongo_cfg.pool_timeout or 1000 * 60
            local pool_size = self.mongo_cfg.pool_size or 30
            conn:set_keepalive(pool_timeout, pool_size)
            ngx.log(ngx.ERR, "db:auth('", tostring(username), "', '***') failed! err:", tostring(err))
            return ok, err
        end
    end
    local coll = db:get_col(self.collname)

    self.conn = conn
    self.db = db
    self.coll = coll
    -- ngx.log(ngx.ERR, "----- init -------")
	return true
end


function _M:uninit()
	if self.conn then
		local pool_timeout = self.mongo_cfg.pool_timeout or 1000 * 60
		local pool_size = self.mongo_cfg.pool_size or 30
		self.conn:set_keepalive(pool_timeout, pool_size)
		self.conn = nil
		self.db = nil
		self.coll = nil
		-- ngx.log(ngx.ERR, "----- uninit ------")
	end
end

-- 参数类型及说明，参见：https://docs.mongodb.org/manual/reference/method/db.collection.createIndex/#db.collection.createIndex
function _M:ensure_index(keys,options, collname)
    options = options or {}
    if util.table_is_array(keys) then
    	local keys_m = t_ordered({})
		for _, key in ipairs(keys) do
			keys_m[key] = 1
		end
		keys = keys_m
    end
    local _keys = t_ordered():merge(keys)
    local index_name = options.name or t_concat(_keys,'_')
	local ns = self.ns
	collname = collname or self.collname
	if collname  then
		ns = self.dbname .. "." .. collname
	end
	local doc = t_ordered({"ns",ns})
    doc.key = _keys
    doc.name = index_name

    for i,v in ipairs({"unique","background", "sparse"}) do
        if options[v] ~= nil then
            doc[v] = options[v] and true or false
            --options[v] = nil
        end
    end

    local sys_idx_coll_name = "system.indexes"
    local sys_idx_coll = self.db:get_col(sys_idx_coll_name)

    local n, err = sys_idx_coll:insert({doc},0, true)

    local ok = (n==0)

    return ok, err, index_name
end

function _M:insert(obj, continue_on_error, safe)
    if type(obj) == 'table' and #obj < 1 then
		obj = {obj}
	end

    local ret, err = self.coll:insert(obj, continue_on_error, safe)
    local ok = err == nil
    return ok, err
end

function _M:upsert(selector, update, upsert, safe, multi)
    if upsert == nil then
        upsert = 1
    end
    if safe == nil then
        safe = 1
    end
    if multi == nil then
        multi = 0
    end
    local ret, err = self.coll:update(selector, update, upsert, multi, safe)
    local ok = err == nil
    return ok, err
end

function _M:delete(selector, singleRemove, safe)
    if singleRemove == nil then
        singleRemove = 0
    end
    if safe == nil then
        safe = 1
    end
    local ret, err = self.coll:delete(selector, singleRemove, safe)
    if err then
    	return false, err
    end

    if ret == 0 then
        return true, "not-exist"
    else
        return true, err
    end
end

-- if found: ret object :
-- {"ok":1,"lastErrorObject":{"updatedExisting":true,"n":1},"value":{"the object field": "the value"}}
-- if not found: ret object:
-- {"ok":1,"lastErrorObject":{"updatedExisting":false,"n":0}}
-- 查找,修改,并返回该对象(只能处理一个对象)
function _M:findAndModify(args)
    local query = args.query    -- document
    local update = args.update  -- document
    local sort = args.sort      -- document
    local fields = args.fields  -- document
    local remove = args.remove  -- boolean(0,1) 好像没作用
    local upsert = args.upsert  -- boolean(0,1) 好像没作用
    local new = args.new        -- boolean(0,1) 好像没作用

    -- https://docs.mongodb.org/v3.0/reference/command/findAndModify/#dbcmd.findAndModify
    local cmd = t_ordered()
    cmd.findAndModify = self.collname
    cmd.query = query
    cmd.update = update
    cmd.sort = sort
    cmd.fields = fields
    cmd.remove = remove
    cmd.upsert = upsert
    cmd.new = new

    local ret, err = self.db:cmd(cmd)
    if err then
    	return false, err
    end
    if ret == nil then
    	return false, "db:cmd failed! ret is nil"
    end

    local ok = ret.ok == 1

    return ok, ret.value
end


function _M:find_one(selector, fields)
    local obj, err = self.coll:find_one(selector, fields)
    if err ~= nil then
    	return false, err
    end
    if obj then
        obj._id = nil
    end
    return true, obj
end

-- 查询,排序,并分页
function _M:find(selector, fields, sortby, skip, limit)
	local objs = {}
	skip = skip or 0
    local cursor, err = self.coll:find(selector, fields, limit)
    if cursor then
    	if skip then
    		cursor:skip(skip)
    	end
    	if limit then
    		cursor:limit(limit)
    	end
    	if sortby then
    		cursor:sort(sortby)
    	end
        for index, item in cursor:pairs() do
            table.insert(objs, item)
        end
    end

    if err then
        return false, err
    else
        return true, objs
    end
end

--[[
args = {
	fields=fields,
	sortby=sortby,
	skip=skip,
	limit=limit,
	cb_args=cb_args, -- args for callback
}
callback: function(obj, cb_args)
]]
function _M:find_foreach(selector, args, callback)
    args = args or {}
    local fields, sortby, skip, limit, cb_args =
    	args.fields, args.sortby, args.skip, args.limit, args.cb_args

	skip = skip or 0
	local count = 0
    local cursor, err = self.coll:find(selector, fields, limit)
    if cursor then
    	if skip then
    		cursor:skip(skip)
    	end
    	if limit then
    		cursor:limit(limit)
    	end
    	if sortby then
    		cursor:sort(sortby)
    	end
        for index, obj in cursor:pairs() do
            local ok, err = callback(obj, cb_args)
            if ok == false then
            	obj._id = nil
            	ngx.log(ngx.ERR, "callback(", json.dumps(obj), ") failed! err:", tostring(err))
            	break
            else
            	count = count + 1
            end
        end
    end

    if err then
        return false, err
    else
        return true, count
    end
end

function _M:query(selector, fields, page, limit)
    page = page or 1
    local offset = (page-1)* limit

    local _, objs, result = self.coll:query(selector, fields, offset, limit, options)

    if result and result.QueryFailure then
        if #objs == 1 then
            return false, objs[1]["$err"]
        else
            return false, "unknow-error"
        end
    end
    return true, objs
end

function _M:count(query)
    local ret, err = self.coll:count(query)

    if err then
        return false, err
    else
        return true, ret
    end
end

function _M:distinct(field, selector)
    local cmd = t_ordered()
    cmd.distinct = self.collname
    cmd.key = field
    cmd.query = selector
    local res, err =  self.db:cmd(cmd)

    if err then
    	return false, err
    end
    if res == nil then
    	return false, "db:cmd failed! res is nil"
    end
    local ok = res.ok == 1

    return ok, res.values
end

function _M:aggregate(pipeline)
    local cmd = t_ordered()
    cmd.aggregate = self.collname
    cmd.pipeline = pipeline
    local res, err =  self.db:cmd(cmd)

    if err then
    	return false, err
    end
    if res == nil then
    	return false, "db:cmd failed! res is nil"
    end
    local ok = res.ok == 1

    return ok, res.result
end

function _M.array_slice(arr, skip, limit)
	if skip or limit then
		skip = skip or 0
		if type(arr) == 'table' and #arr > 0 then
			local begin = skip + 1
			local end_ = #arr
			if limit then
				end_ = skip + limit
			end
			return util.table_slice(arr, begin, end_)
		end
		return nil
	else
		return arr
	end
end

--[[ 目前版本不支持aggregate功能
function _M:aggregate(pipelines)
    local ok, err = self:init()
    if not ok then
        return false, err
    end

    local ok, ret, err = pcall(self.coll.aggregate,self.coll, pipelines)
    --local ok, ret, err = self.coll:aggregate(pipelines)
    self:uninit()
    if ok then
        if err then
            return false, err
        else
            return true, ret
        end
    else
        return ok, ret
    end
end
]]



local func_names = {
	"insert", "upsert", "delete", "ensure_index",
	"findAndModify", "find_one", "find", "find_foreach", "query", "count", "distinct", "aggregate"
}


for _, func_name in ipairs(func_names) do
	local func = _M[func_name]
	if func then
		_M[func_name .. "_raw"] = func
	    _M[func_name] = function (...)
	    	local method = _M[func_name .. "_raw"]
	    	local args = {...}
	    	local self = args[1]
	    	local ok, err = _M.init(self)
		    if not ok then
		        return nil, err
		    end
		    local ok, r1,r2,r3,r4 = pcall(method, ...)
		    _M.uninit(self)
		    if not ok then
		    	return false, r1, r2, r3, r4
		    else
		    	return r1,r2,r3,r4
		    end
	    end
	end
end

local function __FILE__()
    return debug.getinfo(2, "S").short_src
end
_M.src_name = __FILE__()
local hook = require("core.hook")
hook.hook_dao(_M, {new=true, extends=true, init=true, uninit=true})


return _M
