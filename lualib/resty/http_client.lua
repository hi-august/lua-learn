--[[
author: jie123108@163.com
date: 20150901
]]

local _M = {}
local http = require "resty.http"   -- https://github.com/pintsized/lua-resty-http
local cjson = require "cjson"
local dns = require("resty.dns_client")
local uri_count_util = require("core.uri_count_util")

function _M.loads(str)
    local ok, jso = pcall(function() return cjson.decode(str) end)
    if ok then
        return jso
    else
        return nil, jso
    end
end

function _M.startswith(str,startstr)
   return startstr=='' or string.sub(str,1, string.len(startstr))==startstr
end

function _M.new_headers()
    local t = {}
    local lt = {}
    local _mt = {
        __index = function(t, k)
            return rawget(lt, string.lower(k))
        end,
        __newindex = function(t, k, v)
            rawset(t, k, v)
            rawset(lt, string.lower(k), v)
        end,
     }
    return setmetatable(t, _mt)
end

function _M.endswith(str,endstr)
   return endstr=='' or string.sub(str,-string.len(endstr))==endstr
end

function _M.startswith(str,startstr)
   return startstr=='' or string.sub(str,1, string.len(startstr))==startstr
end

function _M.is_encoded(str)
    local pattern = "%%%x%x"
    if string.find(str, pattern) then
        return true
    end
    return false
end

function _M.uri_encode(arg, encodeSlash, cd)
    if not arg then
        return arg
    end
    if _M.is_encoded(arg) then
        return arg
    end
    if encodeSlash == nil then
        encodeSlash = true
    end

    local chars = {}
    for i = 1,string.len(arg) do
        local ch = string.sub(arg, i,i)
        if (ch >= 'A' and ch <= 'Z') or (ch >= 'a' and ch <= 'z') or (ch >= '0' and ch <= '9') or ch == '_' or ch == '-' or ch == '~' or ch == '.' then
            table.insert(chars, ch)
        elseif ch == '/' then
            if encodeSlash then
                table.insert(chars, "%2F")
            else
                table.insert(chars, ch)
            end
        else
            table.insert(chars, string.format("%%%02X", string.byte(ch)))
        end
    end
    return table.concat(chars)
end


_M.dns_query = dns.dns_query
_M.is_ip = dns.is_ip

function _M.headerstr(headers)
    if headers == nil or headers == {} then
        return ""
    end
    local lines = {}
    for k, v in pairs(headers) do
        if type(v) == 'table' then
            v = table.concat(v, ',')
        end
        if k ~= "User-Agent" then
            table.insert(lines, "-H'" .. k .. ": " .. tostring(v) .. "'");
        end
    end
    return table.concat(lines, " ")
end

local function is_json(str)
    return type(str) == 'string' and string.sub(str, 1, 1) == '{' and string.sub(str, #str, #str) == "}"
end

local function create_req_debug(method, uri, myheaders, body)
    local req_debug = ""
    local _k = ""
    if string.sub(uri, 1, 8) == "https://" then
        _k = " -k"
    end
    if method == "PUT" or method == "POST" then
        local debug_body = nil
        local content_type = myheaders["Content-Type"]
        if content_type == nil or _M.startswith(content_type, "text") or _M.endswith(content_type, "json") or _M.startswith(content_type, "application/x-www-form-urlencoded") then
            if string.len(body) < 1024 then
                debug_body = body
            else
                debug_body = string.sub(body, 1, 1024)
            end
        else
            debug_body = "[[not text body: " .. tostring(content_type) .. "]]"
        end
        req_debug = "curl " .. _k .. " -X " .. method .. " " .. _M.headerstr(myheaders) .. " '" .. uri .. "' -d '" .. debug_body .. "' "
    else
        req_debug = "curl " .. _k .. " -X " .. method .. " " .. _M.headerstr(myheaders) .. " '" .. uri .. "' "
    end
    return req_debug
end

_M.create_req_debug = create_req_debug

local function startswith(str,startstr)
   return startstr=='' or string.sub(str,1, string.len(startstr))==startstr
end

local simple_header = {host=true}
local function is_simple_header(header_name) 
    header_name = string.lower(header_name)
    return startswith(header_name, "x-yf") or simple_header[header_name]
end

function _M.get_req_host_port()
    local host = ngx.var.host
    local port = ""
    if ngx.var.server_port and ngx.var.server_port ~= 80 then
        port = ":" .. tostring(ngx.var.server_port)
    end
    local host_port = (ngx.var.scheme or "http") .. "://" .. host .. port
    return host_port
end

-- 获取当前请求的debug信息. curl格式
-- simple_headers 只输出必要的请求头.
function _M.get_req_debug(simple_headers)
    if simple_headers == nil then 
        simple_headers = true
    end
    local method = ngx.req.get_method()
    local uri = _M.get_req_host_port() .. ngx.var.request_uri
    
    local req_headers = ngx.req.get_headers()
    local myheaders = _M.new_headers()
    for k, v in pairs(req_headers) do 
        if simple_headers ==false or is_simple_header(k) then 
            myheaders[k] = v
        end
    end

    local body = nil 
    if method == "PUT" or method == "POST" then
        ngx.req.read_body()
        body = ngx.req.get_body_data()
    end
    local req_debug = create_req_debug(method, uri, myheaders, body)
    return req_debug
end

function _M.ok_json_parse(res)
	local ok=false
    local reason="ERR_SERVER_ERROR"
    local data = nil

    if res then
	    if type(res.headers) == 'table' and res.headers["Content-Type"] and _M.startswith(res.headers["Content-Type"], "application/json") or is_json(res.body) then
	        local jso, err = _M.loads(res.body)
	        if err ~= nil then
	            ngx.log(ngx.ERR, "fail loads(", res.body, ") failed! err:", tostring(err))
	            reason="ERR_JSON_INVALID"
	        else
	            -- 只有OK_JSON格式的数据，才会有这些字段：{ok: true|false, reason="XXX", data={the data}}
	            ok = jso.ok
	            reason = jso.reason
	            data = jso.data
	            -- 可以直接访问res.json来读取响应数据。
	            res.json = jso
	        end
	    end
	    res.ok = ok
	    res.reason = reason
	    res.data = data
	end
end

-- timeout in ms
local function http_req(method, uri, body, myheaders, timeout)

    if myheaders == nil then myheaders = _M.new_headers() end
    local timeout_str = "-"
    if timeout then
        timeout_str = tostring(timeout)
    end

    local proxy = myheaders.proxy
    myheaders.proxy = nil

    local req_debug = create_req_debug(method, uri, myheaders, body)

    ngx.log(ngx.INFO, method, " REQUEST [ ", req_debug, " ] timeout:", timeout_str)
    local httpc = http.new()
    if timeout then
        httpc:set_timeout(timeout)
    end
    local begin = ngx.now()
    local params = {method = method, headers = myheaders, body=body, ssl_verify=false, proxy=proxy}
    -- ngx.log(ngx.ERR, "uri: ", uri, "[[", cjson.encode(params), "]]")
    local res, err = httpc:request_uri(uri, params)
    local cost = ngx.now()-begin
    if not res then
        ngx.log(ngx.ERR, "FAIL REQUEST [ ",req_debug, " ] err:", err, ", cost:", cost)
        res = {status=500, headers={}, body="request failed! err:" .. tostring(err)}
    elseif res.status >= 400 then
        ngx.log(ngx.ERR, "FAIL REQUEST [ ",req_debug, " ] status:", res.status, ", cost:", cost)
    else
        ngx.log(ngx.INFO, "REQUEST [ ",req_debug, " ] status:", res.status, ", cost:", cost)
    end
    if res.status ~= 200 and err == nil then
        err = res.body or "http-error:" .. tostring(res.status)
    end

    if err == nil then
    	_M.ok_json_parse(res)
    end
    if res then
        uri_count_util.count_incr(uri, res.status, cost)
    end

    return res, err, req_debug
end


local function url_302_get(url)
    local cache = ngx.shared.cache
    if cache == nil then
        return nil
    end
    local key = url .. "-302"
    --ngx.log(ngx.DEBUG, "key:", key)
    local url_md5 = ngx.md5(key)
    local v = cache:get(url_md5)
    --ngx.log(ngx.INFO, "cache:get(", url, ",md5:", url_md5 , ",302_url: ", (v or 'nil'))
    if v then
        return v
    else
        return nil
    end
end

local function url_302_set(url, url_302, exptime)
    local cache = ngx.shared.cache
    if cache == nil then
        return
    end
    local key = url .. "-302"
    --ngx.log(ngx.DEBUG, "key:", key)
    local url_md5 = ngx.md5(key)
    local ok, err = cache:set(url_md5, url_302, exptime)
    if ok then
        ngx.log(ngx.INFO, "cache:set(", url, ",md5:", url_md5 , ",302_url: ",url_302, ",exptime:", exptime, ") success")
    else
        ngx.log(ngx.ERR , "cache:set(", url, ",md5:", url_md5 , ",302_url: ",url_302, ",exptime:", exptime, ") failed! err:", err)
    end
end


--支持302的请求
local function http_req_3xx(method, uri, body, myheaders, timeout)
    local req_uri = uri
    local err = ""
    local jump_times = 0
    local max_jump_times = 5
    local res, err, req_debug = nil,nil
    while jump_times < max_jump_times do
        local uri_302 = nil
        for i=1,max_jump_times do
            uri_302 = url_302_get(req_uri)
            if uri_302 and type(uri_302) == 'string' then
                req_uri = uri_302
            else
                if type(uri_302) == 'table' then
                    ngx.log(ngx.ERR, "req_uri:", req_uri, ", 302 uri is a table:", table.concat(uri_302, ","))
                end
                break
            end
        end
        ngx.log(ngx.INFO, "before request: ", req_uri)
        res, err,req_debug = http_req(method, req_uri, body, myheaders, timeout)
        -- 请求错误，或者状态码不等于302/301/307，直接返回。
        if not res or math.floor(res.status/100) ~= 3 then
            if res then
                ngx.log(ngx.INFO, "after request: [",req_debug,"] res.status[", res.status, "]...")
            end
            return res, err, req_debug
        end

        jump_times = jump_times + 1
        ngx.log(ngx.INFO, "res.status[", res.status, "],res.body:[", res.body, "]")
        if type(res.headers) == "table" and res.headers["Location"] ~= nil then
            local uri_302 = res.headers["Location"]
            if uri_302 == nil then
                ngx.log(ngx.ERR, "302 response Location missing!")
                return res, "Location missing", req_debug
            else
                if type(uri_302) == 'table' then
                    ngx.log(ngx.ERR, "request: [",req_debug,"] Location is a table :", table.concat(uri_302, ","))
                    uri_302 = uri_302[#uri_302]
                end
                ngx.log(ngx.WARN, "302 Location:", uri_302)
                local url_302_cache_exptime = 60*5
                url_302_set(req_uri,uri_302, url_302_cache_exptime)
                req_uri = uri_302
            end
        else
            ngx.log(ngx.ERR, "302 response Location missing!")
            return res, "Location missing", req_debug
        end
    end
    if jump_times == max_jump_times then
        err = "reach the max jump times"
        ngx.log(ngx.INFO, "reach the max jump times")
    end
    return res, err, req_debug
end

function _M.http_get(uri, myheaders, timeout)
    return http_req_3xx("GET", uri, nil, myheaders, timeout)
end

function _M.http_del(uri, myheaders, timeout)
    return http_req_3xx("DELETE", uri, nil, myheaders, timeout)   
end

function _M.http_post(uri, body, myheaders, timeout)
    return http_req_3xx("POST", uri, body, myheaders, timeout)
end

function _M.http_put(uri,  body, myheaders, timeout)
    return http_req_3xx("PUT", uri, body, myheaders, timeout)
end

return _M
