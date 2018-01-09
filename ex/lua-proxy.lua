--[[
Ensure your http proxy http://172.17.0.1:8118 wokring

$ curl -x http://172.17.0.1:8118 http://v4.ident.me/ -v

$ docker run -it --rm --name openresty -d openresty/openresty:jessie
$ docker exec -it openresty /bin/bash

docker$ sed -i 's!#error_log stderr debug;!error_log stderr debug;!' /usr/local/openresty/bin/resty
docker$ opm install pintsized/lua-resty-http

docker$ curl https://gist.githubusercontent.com/vkill/0a35fc705707f93939f1eee6ddcd4a67/raw/7eb84e5307937c11d025661d4276fb532b41dfae/lua-resty-http_example_with_http_proxy.lua -o test.lua
docker$ resty test.lua

docker$ exit

$ docker stop openresty

--]]
package.path = '/opt/yf-filminfo/lua/?.lua;/opt/yf-filminfo/libs/?.lua;/opt/lua-resty-baselib/libs/?.lua;/opt/lua-resty-baselib/libs/?/init.lua;/opt/lua-resty-stats/lib/?/init.lua;./?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/lib/lua/5.1/?.lua;/usr/local/lib/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua'

local cjson = require("cjson")
local http = require "resty.http"

--
-- curl -x http://172.17.0.1:8118 https://www.baidu.com/ -v -o /dev/null
--

local httpc = http.new()

httpc:set_timeout(5000)

local ok, err = httpc:connect('172.17.0.1', 8118)
if not ok then
  ngx.say("failed to connect: ", err)
  return
end

local res, err = httpc:request({
  method = 'CONNECT',
  path = 'www.baidu.com:443',
  headers = {
    ['Host'] = 'www.baidu.com:443',
    ['User-Agent'] = 'curl/7.38.0',
    ['Proxy-Connection'] = 'Keep-Alive'
  }
})

if not res or res.status ~= 200 then
  ngx.say("failed to establish HTTP proxy tunnel: ", err)
  return
end

local ok, err = httpc:ssl_handshake(nil, 'www.baidu.com:443', false)
if not ok then
  ngx.say("failed to ssl_handshake: ", err)
  return
end

local res, err = httpc:request({
  method = 'GET',
  -- path = '/',
  path = 'https://www.baidu.com:443/',
  headers = {
    ['Host'] = 'www.baidu.com',
    ['User-Agent'] = 'curl/7.38.0'
  }
})

if not res then
  ngx.say("failed to request: ", err)
  return
end

local body, err = res:read_body()
if body then
  res.body = body
end

ngx.say("status: ", res.status)
ngx.say("headers: ", cjson.encode(res.headers))
ngx.say("body: ", res.body)

httpc:close()

--
-- curl -x http://172.17.0.1:8118 http://www.baidu.com/ -v -o /dev/null
--

local httpc = http.new()

httpc:set_timeout(5000)

local ok, err = httpc:connect('172.17.0.1', 8118)
if not ok then
  ngx.say("failed to connect: ", err)
  return
end

local res, err = httpc:request({
  method = 'GET',
  path = 'http://www.baidu.com:80/',
  headers = {
    ['Host'] = 'www.baidu.com',
    ['User-Agent'] = 'curl/7.38.0',
    ['Proxy-Connection'] = 'Keep-Alive'
  }
})

if not res then
  ngx.say("failed to request: ", err)
  return
end

local body, err = res:read_body()
if body then
  res.body = body
end

ngx.say("status: ", res.status)
ngx.say("headers: ", cjson.encode(res.headers))
ngx.say("body: ", res.body)

httpc:close()
