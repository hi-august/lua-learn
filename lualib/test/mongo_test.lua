local tb    = require "resty.iresty_test"
local json = require("core.json")
local test = tb.new({unit_name="test-mongo-test"})
local mongo_dao_cache = require("resty.mgo.mongo_dao_cache")

local debug = true
local data_cnt = 10

local ngx_log = function(...) end
if debug then
	ngx_log = ngx.log
end

local mongo_cfg = {
	host="127.0.0.1",
	port=27017,
	dbname = "test",
	timeout = 1000*15,
}

function tb:init( )
	local list_fields = {
		fid=true,
		name=true,
		alias=true,
		age=true,
		remark=true,
		images=true,
	}
	local id_field = 'fid'
	local cachename = 'cache'
	local cache_prefix = "f:"
	local cache_exptime = 100
	local args = {
		list_fields=list_fields,
		detail_fields=list_fields,
		cachename=cachename,
		cache_prefix=cache_prefix,
		cache_exptime=cache_exptime,
	}
	tb.mgo = mongo_dao_cache:new(mongo_cfg, "mgo_test", id_field, args)
end

function tb:test_001_create_index()
	local ok, err = tb.mgo:ensure_index({"fid"},{unique=true});

	ngx_log(ngx.ERR, "INDEX: ok:", ok, ", err:", tostring(err))
	if not ok then
		error(err)
	end
	local ok, err = tb.mgo:delete({}, nil, true)
	ngx_log(ngx.ERR, "DELETE: ok:", ok, ", err:", tostring(err))
	if not ok then
		error(err)
	end
end

local function create_test_obj(prefix, i)
	local obj = {
		fid=i,
		name=string.format("%s-name: %d", prefix, i),
		alias=string.format("%s-alias: %d", prefix, i),
		age=i,
		remark=string.format("%s-remark: %d", prefix, i),
		images={string.format("%s-image-%d-1.jpg", prefix, i)},
	}
	return obj
end

local cache = {}

function tb:test_002_insert()
	for i=1, math.floor(data_cnt/2)+1 do
		local obj = create_test_obj("new", i)
		local ok, err = tb.mgo:insert(obj, 1, 0)
		ngx_log(ngx.ERR, "INSERT: ok: ", tostring(ok), ", err:", tostring(err))
		if not ok then
			error(err)
		end
		cache[tostring(obj.fid)] = obj
	end
end

function tb:test_003_upsert()
	for i=math.floor(data_cnt/2)-1, data_cnt do
		local obj = create_test_obj("upsert", i)
		local selector = {fid=obj.fid}
		local update = {["$set"] = obj}
		local ok, err = tb.mgo:upsert(selector, update, true, true)
		ngx_log(ngx.ERR, "UPSERT: ok: ", tostring(ok), ", err:", tostring(err))
		if not ok then
			error(err)
		end
		cache[tostring(selector.fid)] = obj
	end
end

function tb:test_004_delete()
	for i=1, data_cnt, 2 do
		local selector = {fid=i}
		local ok, err = tb.mgo:delete(selector, 1, 1)
		ngx_log(ngx.ERR, "DELETE: ok: ", tostring(ok), ", err:", tostring(err))
		if not ok then
			error(err)
		end
		cache[tostring(selector.fid)] = nil
	end
end

function tb:test_005_find_and_modify()
	local args = {
		query = {["fid"]={["$gte"]=4}},
		update = {["$set"]={extinfo="find_and_modify"}},
		sort = {fid = -1},
	}
	local ok, obj = tb.mgo:findAndModify(args)
	if obj then
		obj._id = nil
	end
	ngx_log(ngx.ERR, "FindAndModify: ok: ", tostring(ok), ", obj:", json.dumps(obj))
	if not ok then
		error(err)
	end
end

local function err_msg(name, obj, exp_obj, field_name)
	local err_fmt = "%s:%s expect val: %s(%s), but got val: %s(%s)"
	return string.format(err_fmt, name, field_name, exp_obj[field_name],
			type(exp_obj[field_name]), obj[field_name], type(obj[field_name]))
end

local function check_obj_equals(name, obj, exp_obj)
	if type(exp_obj) == 'table' and type(obj) == 'table' then
		if exp_obj.fid ~= obj.fid then
			local err = err_msg(name, obj, exp_obj, "fid")
			error(err)
		end
		if exp_obj.name ~= obj.name then
			local err = err_msg(name, obj, exp_obj, "name")
			error(err)
		end
		if exp_obj.remark ~= obj.remark then
			local err = err_msg(name, obj, exp_obj, "remark")
			error(err)
		end
	elseif obj == nil and exp_obj == nil then
		-- pass
	else
		local err = string.format("%s: expect obj: %s, but got obj: %s", name, json.dumps(exp_obj), json.dumps(obj))
		error(err)
	end

end

function tb:test_006_find_one()
	for i=1, data_cnt do
		local fid = i
		local selector = {fid=fid}
		local fields = nil
		local ok, obj = tb.mgo:find_one(selector, fields)
		if obj then
			obj._id = nil
		end
		ngx_log(ngx.ERR, "fid: ", fid, ", ok:", ok, ", obj: ", json.dumps(obj))
		if not ok then
			error(obj)
		end
		local exp_obj = cache[tostring(fid)]
		check_obj_equals("find_one", obj, exp_obj)
	end
end

--
function tb:test_007_find_all()
	local selector = {}
	local fields = nil
	local sortby = {fid=-1}
	local skip = 0
	local limit = 100
	local ok, objs = tb.mgo:find(selector, fields, sortby, skip, limit)
	if not ok then
		error(objs)
	end

	for i, obj in ipairs(objs) do
		obj._id = nil
		local fid = obj.fid
		local exp_obj = cache[tostring(fid)]
		check_obj_equals("find_one", obj, exp_obj)
	end
end

-- TODO: test find_foreach
-- TODO: test query

function tb:list_by_ids_check(ids, expect_cache)
	local ok, objs = self.mgo:list_by_ids(ids)
	if not ok then
		error(objs)
	end
	for i, obj in ipairs(objs) do
        if obj.__cache ~= expect_cache then
            ngx.say(string.format("obj{fid: %s}.__cache = %s, expect: %s", obj.fid, obj.__cache, expect_cache))
        end
	end
end

function tb:test_020_list_by_ids()
	self.mgo:flush_all(true)
	local ids = {}
	for i=1, data_cnt do
		table.insert(ids, i)
	end
    self:list_by_ids_check(ids, "miss")
    self:list_by_ids_check(ids, "hit")
end

function tb:test_021_test_upsert_del_cache()
	local selector = {}
	local args = {
		cb_args={mgo=self.mgo},
	}
	local callback = function(obj, args)
		local upsert_sel = {fid=obj.fid}
		local update = {["$set"]={upsert_del_cache=true}}
		local ok, err = args.mgo:upsert(upsert_sel, update, 0, 1)
		if not ok then
			error(err)
		end
	end
	local ok, count = self.mgo:find_foreach(selector, args, callback)
	if not ok then
		error(count)
	end

	local ids = {}
	for i=1, data_cnt do
		table.insert(ids, i)
	end
	self:list_by_ids_check(ids, "miss")
end

-- units test
test:run()

-- bench units test
-- test:bench_run()
