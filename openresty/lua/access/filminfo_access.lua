local config = require("config")
local http_client = require("resty.http_client")

local function main()
    if config.debug_req_body then
        local req_debug = http_client.get_req_debug()
        ngx.log(ngx.WARN, "===[ ", req_debug, " ]")
    end
end

local ok, err = pcall(main)
if not ok then
    ngx.log(ngx.ERR, "filminfo access main failed! err:", tostring(err))
end
