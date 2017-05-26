-- ngx.say("test")
local json = require("core.json")
-- local viewutil = require("core.viewutil")

local function filminfo_find()
    local args = ngx.req.get_uri_args()
    -- curl -i 127.0.0.1:8100/filminfo/find\?type=2\&source=hhh
    -- {"reason":"","ok":true,"data":{"films":{"type":"2","source":"hhh"}}}
    return json.ok({ films = args})
end


-- 构造路由
local router = {
    ["/filminfo/find"] = filminfo_find,
}

local uri = ngx.var.uri
ngx.header['Content-Type'] = "application/json;charset=UTF-8"

if router[uri] then
    local resp = router[uri]()
    if resp then
        if type(resp) == 'table' then
            resp = json.dumps(resp)
        end
        -- 输出响应
        ngx.say(resp)
    end
else
    ngx.log(ngx.ERR, "invalid request [", uri, "]")
    ngx.exit(404)
end
