-- 启动openresty,使用完整路径
-- sudo /usr/local/ngx_openresty/nginx/sbin/nginx -c /home/august/lua-learn/openresty/conf/nginx.conf -s reload
-- ngx.say("test")

local json = require("core.json")
local viewutil = require("core.viewutil")

local function test_get()
    local args = ngx.req.get_uri_args()
    -- curl使用\转义
    -- curl -i 127.0.0.1:8100/test/get\?method=get\&source=m1905
    return json.ok({ films = args})
end

local function test_post()
    ngx.req.read_body()
    local json_str = ngx.req.get_body_data()
    local args = viewutil.check_post_json(json_str)
    -- curl -i '127.0.0.1:8100/test/post' -d '{"method": "post", "source": "mtime"}'
    return json.ok({ films = args})
end

-- 构造路由
local router = {
    -- get请求
    ["/test/get"] = test_get,
    -- post请求
    ["/test/post"] = test_post,
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
