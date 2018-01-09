
local _M = {}

-- callback 函数返回值，必须是：
--      成功：true, data
--      失败：false, error
-- times 重试次数 默认3次
-- sleep_second 重试间隔，单位秒(可用小数标识毫秒)，默认是0.3秒
function _M.retry_(times, sleep_second, callback, ...)
    local values = nil
    local err_level = ngx.WARN
    times = times or 3
    sleep_second = sleep_second or 0.3
    for i =1, times do 
        values = {callback(...)}
        local ok, err = values[1], values[2]
        if ok or (ok == nil and err == nil) then 
            break 
        else
            if i == times then 
                err_level = ngx.ERR 
            end
            ngx.log(err_level, tostring(err))
            if i < times and sleep_second > 0 then
                ngx.sleep(sleep_second)
            end
        end     
    end

    return unpack(values, 1, math.max(10, #values))
end

-- 默认的retry函数。
function _M.retry(callback, ...)
    return _M.retry_(nil, nil, callback, ...)
end

-- callback 函数返回值，必须是http_client中的方法的返回值：
--     res, err, req_debug
-- times 重试次数 默认3次
-- sleep_second 重试间隔，单位秒(可用小数标识毫秒)，默认是0.3秒
function _M.http_retry_(times, sleep_second, callback, ...)
    local values = nil
    local err_level = ngx.WARN
    times = times or 3
    sleep_second = sleep_second or 0.3
    for i =1, times do 
        values = {callback(...)}
        local res, err, req_debug = values[1], values[2], values[3]
        -- 错误码不是500,直接返回。
        if math.ceil(res.status/100) ~= 5 then 
            break 
        else
            if i == times then 
                err_level = ngx.ERR 
            end
            ngx.log(err_level, "request [", tostring(req_debug), "] failed! reason:", tostring(res.reason), ", err:", tostring(err))
            if i < times and sleep_second > 0 then
                ngx.sleep(sleep_second)
            end
        end     
    end

    return unpack(values,1, 10)
end

function _M.http_retry(callback, ...)
    return _M.http_retry_(nil, nil, callback, ...)
end

-- 类的方法，写在_C里面,这样可以使用与_M同名的函数。
local _C = {}
local mt = {__index = _C}

-- 如果要指定times,sleep_second,可以实例化一个对象，并指定相关参数。
function _M:new(times, sleep_second)
    return setmetatable({times=times,sleep_second=sleep_second}, mt)
end

-- 实例化之后，调用的retry函数。
function _C:retry(callback, ...)
    return _M.retry_(self.times, self.sleep_second, callback, ...)
end

--[[ 使用示例
local retry = require("core.retry")
local cjson = require("cjson")

local function myrequest(a, b, c)
    return false, string.format("a=%s, b=%s, c=%s", a, b, c)
end

-- 使用默认的参数，重试3次，间隔0.3秒
local ok, obj = retry.retry(myrequest, 3, 4, 5)
print("retry.retry ==> ok:", ok, " obj:", cjson.encode(obj))

-- 使用非默认参数时，需要实例化。
local r = retry:new(5, 0.1)
local ok, obj = r:retry(myrequest, 3, 4, 5)
print("r:retry ==> ok:", ok, " obj:", cjson.encode(obj))
]]

return _M