local mongo_dao_cache = require("resty.mgo.mongo_dao_cache")
local util = require("core.util")

local _M = {}

local mt = { __index = _M }

function _M:new(mongo_cfg)
	assert(mongo_cfg ~= nil)
	local collname = "test_grandson"
	local id_field = "id"
	local cachename = "cache"
	local cache_prefix = "t:"
	local cache_exptime = 300

	local args = {
		-- list_fields=list_fields,
		-- detail_fields=detail_fields,
		cachename=cachename,
		cache_prefix=cache_prefix,
		cache_exptime=cache_exptime,
	}
	local obj = mongo_dao_cache:new(mongo_cfg, collname, id_field, args)

	return obj:extends(_M)
end

-- @overwrite
function _M:get_by_id(id)
	local ok, obj = self.supers[_M].get_by_id(self, id)
	-- ngx.log(ngx.ERR,"grandson get_by_id ")
	return ok, obj
end

local function __FILE__()
    return debug.getinfo(2, "S").short_src
end
_M.src_name = __FILE__()
local hook = require("core.hook")
hook.hook_dao(_M, {new=true, extends=true, init=true, uninit=true})


return _M
