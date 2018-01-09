-- resty -I . test/test_mgo.lua
local mongo_dao = require("resty.mgo.mongo_dao")

local mongo_cfg = {
	host = "127.0.0.1",
	port = 27017,
	dbname = "filminfo",
	timeout = 1000*15,
}


local dao = mongo_dao:new(mongo_cfg, "filminfo")
local selector = {}
local fields = nil
local sortby = {fid=1}
local skip = 200
local limit = 10
ngx.update_time()
local begin = ngx.time()

local ok, objs = dao:find(selector, fields, sortby, skip, limit)
if ok then
	for i, obj in ipairs(objs) do
		ngx.log(ngx.ERR, i," : ", obj.fid, ', name: ', obj.name)
	end
end
ngx.update_time()
local _end = ngx.time()
local cost = _end - begin
ngx.log(ngx.ERR, "--- cost:", cost)
