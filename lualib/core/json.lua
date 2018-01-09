local cjson = require "cjson"

local _M = {}


cjson.encode_empty_table_as_object(false)

function _M.loads(str)
    local ok, jso = pcall(function() return cjson.decode(str) end)
    if ok then
        return jso
    else
        return nil, jso
    end
end


function _M.endswith(str,endstr)
   return endstr=='' or string.sub(str,-string.len(endstr))==endstr
end

function _M.startswith(str,startstr)
   return startstr=='' or string.sub(str,1, string.len(startstr))==startstr
end

local function is_json_simple(str)
    local fc = string.sub(str,1, 1)
    local lc = string.sub(str, -1)
    if fc == "{" and lc == "}" then 
        return true 
    elseif fc == "[" and lc == "]" then 
        return true 
    end
    return false
end

-- 判断str是否是json，如果是才loads，否则直接返回原来的值。
function _M.tryloads(str)
    if type(str) == 'string' then 
        if is_json_simple(str) then 
            local ok, jso = pcall(function() return cjson.decode(str) end)
            if ok then
                return jso
            end 
        end
    end
    return str 
end

function _M.dumps(tab)
	if tab and type(tab) == 'table' then
		return cjson.encode(tab)
	else
		return tostring(tab)
	end
end

function _M.fail(reason, data)
    if reason == "ERR_SERVER_ERROR" then 
        ngx.status = 500
    end
    return {ok=false, reason=reason, data=data}
end

function _M.ok(data, reason)
    return {ok=true, reason= reason or "", data=data}
end

return _M