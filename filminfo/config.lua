local _M = {}

-- 影视库使用的mongodb配置。
_M.mongo_cfg = {
	host = "127.0.0.1",
	port = 27017,
	dbname = "filminfo",
	timeout = 1000*30,
}

_M.spider_mongo_cfg = {
	host = "127.0.0.1",
	port = 27017,
	dbname = "nf_spider",
	timeout = 1000*30,
}

_M.ext_config = "filminfo"
_M.prefix = '/opt/lua-learn/'

_M.debug = true
_M.debug_req_body = true

local function init_from_ext_config()
    local confutil = require("core.config_util")
    return confutil.init_from_ext_config(_M)
end

local ok, exp = pcall(init_from_ext_config)
if not ok then
    if ngx then
        ngx.log(ngx.ERR, "call init_from_ext_config() failed! err:", exp)
    end
end

return _M
