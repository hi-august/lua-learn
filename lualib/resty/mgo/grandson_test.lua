local tb    = require "resty.iresty_test"
local json = require("core.json")
local test = tb.new({unit_name="test-grandson"})
local grandson_dao = require("resty.mgo.mongo_dao_grandson")

local debug = false

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
	tb.mgo = grandson_dao:new(mongo_cfg)
end

function tb:test_grandson()
	local ok, err = tb.mgo:get_by_id(10)

	ngx_log(ngx.ERR, "GET BY ID: ok:", ok, ", err:", tostring(err))
	if not ok then
		error(err)
	end
end


-- units test
test:run()

-- bench units test
-- test:bench_run()
