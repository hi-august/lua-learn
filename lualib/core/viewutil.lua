local json = require("core.json")
local apierror = require("core.apierror")


local _M = {}


function _M.check_post_json(json_str)
	local args, err = json.loads(json_str)
	if args == nil or type(args) ~= 'table' then 
		ngx.log(ngx.ERR, "load json failed! err:", tostring(err))
		if json_str and #json_str < 1024 then 
			ngx.log(ngx.ERR, "json [[", json_str, "]]")
		end
		ngx.status = 400
		local ok_json = {ok=false, reason=apierror.ERR_ARGS_INVALID}
		ngx.say(json.dumps(ok_json))
		ngx.exit(0)
	end
	return args
end

function _M.check_field(jso, field)
	local value = jso[field]
	if value == nil or value == "" then 
		ngx.log(ngx.ERR, "args '" .. field .. "' missing!")
		ngx.status = 400
		local ok_json = {ok=false, reason=apierror.ERR_ARGS_INVALID}
		ngx.say(json.dumps(ok_json))
		ngx.exit(0)
	end
	return value
end

function _M.check_int_field(jso, field)
	local value = _M.check_field(jso, field)
	value = tonumber(value)
	if not value then
		ngx.log(ngx.ERR, "args '" .. field .. "' error!")
		ngx.status = 400
		local ok_json = {ok=false, reason=apierror.ERR_ARGS_INVALID}
		ngx.say(json.dumps(ok_json))
		ngx.exit(0)
	end  
	return value
end

function _M.check_int_array_field(jso, field)
	-- res_ids
	local value = jso[field]
	if value == nil or type(value) ~= 'table' then 
		ngx.log(ngx.ERR, "args '" .. field .. "' missing or invalid! must be a array")
		ngx.status = 400
		local ok_json = {ok=false, reason=apierror.ERR_ARGS_INVALID}
		ngx.say(json.dumps(ok_json))
		ngx.exit(0)
	end

	local arr = {}
	for _, v in ipairs(value) do 
		if type(v) == 'string' then 
			v = tonumber(v)
		end
		if type(v) == 'number' then 
			table.insert(arr, v)
		else 
			ngx.log(ngx.ERR, "args ", field, "'s value [", v, "] invalid!")
			ngx.status = 400
			local ok_json = {ok=false, reason=apierror.ERR_ARGS_INVALID}
			ngx.say(json.dumps(ok_json))
			ngx.exit(0)
		end
	end

	return arr
end


function _M.check_array_field(jso, field)
	-- res_ids
	local value = jso[field]
	if value == nil or type(value) ~= 'table' then 
		ngx.log(ngx.ERR, "args '" .. field .. "' missing or invalid! must be a array")
		ngx.status = 400
		local ok_json = {ok=false, reason=apierror.ERR_ARGS_INVALID}
		ngx.say(json.dumps(ok_json))
		ngx.exit(0)
	end

	return value
end

function _M.check_empty_string_array_field(jso, field)
	local value = jso[field]
	local arr = {}
	if value == nil or type(value) ~= 'table' then
        return arr
	end
	for _, v in ipairs(value) do
	    local is_empty = _M.check_empty_content(v)
		if is_empty then
			ngx.log(ngx.ERR, "args ", field, "'s value [", v, "] invalid!")
        else
            if type(v) == 'string' then
                table.insert(arr, v)
            end
		end
	end
	return arr
end

function _M.check_empty_content(str)
	local map_empty_char = {
		[' '] = true,
		['\r'] = true,
		['\n'] = true,
	}

	local empty_len = 0
	local str_len = #str
	for index = 1, str_len do
		local ch = string.sub(str, index, index)
		if map_empty_char[ch] then
			empty_len = empty_len + 1
		end
	end

	if str_len == empty_len then
		return true
	end

	return false
end

local ok_types = {
	[1]="article", -- 有料文章
	[2]="comment", --评论。
	[3]="film", -- 影片，视频
	[4]="filmlist", --片单
	[5]="wemedia_video", --自媒体视频。
	[9]="block", --bloc类型
	[10]="topic", --话题
    [11] = "commentary",
    [15] = "discuss",
	[16] = "question", -- 活动问答
	[17] = "news" -- 快讯
}

function _M.check_type_field(jso, field)
	local type_ = _M.check_int_field(jso, field)
	if ok_types[type_] == nil then 
		ngx.log(ngx.ERR, "unknow like type [", tostring(type_), "] ...")
		ngx.status = 400
		local ok_json = {ok=false, reason=apierror.ERR_ARGS_INVALID}
		ngx.say(json.dumps(ok_json))
		ngx.exit(0)
	end
	return type_
end

return _M
