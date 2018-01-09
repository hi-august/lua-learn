--[[
author: liuxiaojie@leomaster.com
date: 20151103
]]
local base64 = require('core.mybase64');

local _M = {}
local ffi = require("ffi")
ffi.cdef[[
int rename(const char *oldpath, const char *newpath);
int system(const char *command);
int access(const char *pathname, int mode);
int unlink(const char *pathname);
int remove(const char *pathname);
char *strerror(int errnum);
int open(const char *pathname, int flags, uint64_t mode);
int close(int fd);
uint64_t read(int fd, void *buf, uint64_t count);
uint64_t write(int fd, const void *buf, uint64_t count);
]]

function BitValue(bit)
    local val = 1
    for i=1, bit do
        val = val * 2
    end
    return val
end

function _M.is_url_encoded(var)
    local m, err = ngx.re.match(var, "%[0-9a-fA-F]{2}")
    if m then
        return true
    else
        return false
    end
end

function _M.safecopy(src, dest)
    local cmd = string.format("cp -rf '%s' '%s'", src, dest)
    local ret = os.execute(cmd)
    local ok = (ret == 0)
    local errmsg = nil
    if not ok then
        errmsg = "copy file failed!"
    end
    return ok, errmsg
end

function _M.rename(oldfilename,newfilename)
    local ret = tonumber(ffi.C.rename(oldfilename, newfilename))
    if ret ~= 0 then
        if ffi.errno() == 18 then --Invalid cross-device link
            local ok, err = _M.safecopy(oldfilename, newfilename)
            if ok then
                ok, err = _M.unlink(oldfilename)
            end

            return ok, err
        end
        local errmsg = ffi.string(ffi.C.strerror(ffi.errno()))
        return false, errmsg
    end
    return true
end

function _M.unlink(filename)
  local ret = tonumber(ffi.C.unlink(filename))
    if ret == 0 then
        ngx.log(ngx.INFO, "file (", filename, ") unlink success!")
        return true
    else
        local err = ffi.string(ffi.C.strerror(ffi.errno()))
        ngx.log(ngx.ERR, "unlink(", filename, ") failed! err:", err)
        return false, err
    end
end

function _M.math_mod(a, b)
	return a - math.floor(a/b)*b
end

function _M.exist(filename)
    return tonumber(ffi.C.access(filename, 0)) == 0
end

function _M.mkdir(dir)
    local cmd = "mkdir -p '" .. dir .. "'"
    local ret = os.execute(cmd)
    return ret==0, ret
end

function _M.pathinfo(path)
    local pos = string.len(path)
    local extpos = pos + 1
    while pos > 0 do
        local b = string.byte(path, pos)
        if b == 46 then -- 46 = char "."
            extpos = pos
        elseif b == 47 then -- 47 = char "/"
            break
        end
        pos = pos - 1
    end

    local dirname = string.sub(path, 1, pos)
    local filename = string.sub(path, pos + 1)
    extpos = extpos - pos
    local basename = string.sub(filename, 1, extpos - 1)
    local extname = string.sub(filename, extpos)
    return {
        dirname = dirname,
        filename = filename,
        basename = basename,
        extname = extname
    }
end

function _M.str_is_empty(str)
    return type(str) ~= 'string' or _M.trim(str) == ""
end

function _M.table_is_empty(t)
    return t == nil or next(t) == nil
end

function _M.table_is_array(t)
  if type(t) ~= "table" then return false end
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then return false end
  end
  return true
end

function _M.table_merge(a, b)
    local res = {}
    if a then
        for k, v in pairs(a) do
            res[k] = v
        end
    end
    if b then
        for k, v in pairs(b) do
            res[k] = v
        end
    end
    return res
end

_M.table_marge = _M.table_merge

function _M.table_slice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

function _M.table_copy(t)
    local res = {}
    if t then
        for k, v in pairs(t) do
            res[k] = v
        end
    end
    return res
end

function _M.array_marge(a, b)
    local res = {}
    for _, v in ipairs(a) do
        table.insert(res, v)
    end
    for _, v in ipairs(b) do
        table.insert(res, v)
    end
    return res
end

function _M.table_is_map(t)
  if type(t) ~= "table" then return false end
  for k,_ in pairs(t) do
    if type(k) == "number" then  return false end
  end
  return true
end

-- table继承
function _M.table_extends(o_table, t_table)
    table.foreach(t_table, function(k, v)
        if type(k) == 'number' then
            table.insert(v)
        else
            if o_table[k] ~= nil and type(v) == 'table' and type(o_table[k]) == 'table' then
                _M.table_extends(o_table[k], v)
            else
                o_table[k] = v
            end
        end
    end)
    return o_table
end

-- 获取多纬数组中的一列
function _M.table_column(t, key, bIndex)
    local result = {}
    local slots = {}
    for k, v in pairs(t) do
        if v[key] then
            table.insert(result, v[key])
            if bIndex then
                slots[tostring(v[key])] = k
            end
        end
    end
    return result, slots
end

-- 交换数组的键和值
function _M.table_flip(t)
    local result = {}
    for k,v in pairs(t) do
        result[v] = k
    end
    return result
end

-- 将table中的key作为一个数组返回
function _M.table_keys(t)
	local keys = {}
	for k,_ in pairs(t) do
		table.insert(keys, k)
	end
	return keys
end

-- 将table中的key作为一个数组返回
function _M.table_values(t)
    local values = {}
    for _,v in pairs(t) do
        table.insert(values, v)
    end
    return values
end

function _M.ifnull(var, value)
    if var == nil then
        return value
    end
    return var
end

function _M.trim (s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function escape(s)
    return string.gsub(s, '[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1')
end

function _M.mongo_escape(s)
    return string.gsub(s, '[%-%.%+%[%]%(%)%$%^%%%?%*]', '\\%1')
end

function _M.replace(s, s1, s2)
    local str = string.gsub(s, escape(s1), s2)
    return str
end

function _M.endswith(str,endstr)
   return endstr=='' or string.sub(str,-string.len(endstr))==endstr
end

function _M.startswith(str,startstr)
   return startstr=='' or string.sub(str,1, string.len(startstr))==startstr
end


function _M.popen(cmd, filter)
    local fp = io.popen(cmd .. '; echo "retcode:$?"', "r")
    local line_reader = fp:lines()
    local lines = {}
    local lastline = nil
    for line in line_reader do
        lastline = line
        if not _M.startswith(line, "retcode:") then
            if filter == nil then
                table.insert(lines, line)
            else
                line = filter(line)
                if line ~= nil then
                    table.insert(lines, line)
                end
            end
        end
    end
    fp:close()
    if lastline == nil or string.sub(lastline, 1, 8) ~= "retcode:" then
        return false, lastline, -1
    else
        local code = tonumber(string.sub(lastline, 9))
        return code == 0, lines, code
    end
end

-- ngx.log(ngx.INFO, "config.idc_name:", config.idc_name, ", config.is_root:", config.is_root)
-- delimiter 应该是单个字符。如果是多个字符，表示以其中任意一个字符做分割。
function _M.split(s, delimiter)
    local result = {};
    for match in string.gmatch(s, "[^"..delimiter.."]+") do
        table.insert(result, match);
    end
    return result;
end

-- delim 可以是多个字符。
-- maxNb 最多分割项数
function _M.splitex(str, delim, maxNb)
    -- Eliminate bad cases...
    if delim == nil or string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0    -- No limit
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gmatch(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if maxNb > 0 then
            if nb == maxNb-1 then break end
        end
    end
    -- Handle the last field
    if nb == maxNb-1 or lastPos < #str+1 then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
end

function _M.initrandom()
    math.randomseed(ngx.now())
end
_M.initrandom()

function _M.random_choice(arr)
    if arr == nil then
        return nil
    end
    return arr[math.random(1, #arr)]
end


function _M.random_sample(str, len)
    local t= {}
    for i=1, len do
        local idx = math.random(#str)
        table.insert(t, string.sub(str, idx,idx))
    end
    return table.concat(t)
end


-- callback 函数返回值，必须是：
--      成功：true, data
--      失败：false, error
-- times 重试次数
-- sleep_second 重试间隔，单位秒(可用小数标识毫秒)
function _M.retry(callback, times, sleep_second)
    local ok, err = nil
    local err_level = ngx.WARN
    times = times or 3
    sleep_second = sleep_second or 0.3
    for i =1, times do
        ok, err = callback()
        if ok then
            break
        else
            if i == times then
                err_level = ngx.ERR
            end
            ngx.log(err_level, err)
            if i < times and sleep_second > 0 then
                ngx.sleep(sleep_second)
            end
        end
    end

    return ok, err
end

-- callback 函数返回值，必须是：
--      成功：true, data
--      失败：false, error
-- times 重试次数
-- sleep_second 重试间隔，单位秒(可用小数标识毫秒)
function _M.retry2(times, sleep_second, callback, ...)
    local values = nil
    local err_level = ngx.WARN
    times = times or 3
    sleep_second = sleep_second or 0.3
    for i =1, times do
        values = {callback(...)}
        local ok, err = values[1], values[2]
        if ok then
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

    return unpack(values)
end

-- 根据白名单过滤对象。(白名单以外的属性将被过滤掉)
-- fields 格式为：{field1=true, field2=true}
function _M.filter_field_white(obj, fields)
    if not obj or type(obj) ~= 'table' or not fields then
        return
    end
    for k, v in pairs(obj) do
        if not fields[k] then
            obj[k] = nil
        end
    end
end

-- 根据白名单过滤对象，并将被过滤的对象返回(白名单以外的属性将被过滤掉)
-- fields 格式为：{field1=true, field2=true}
function _M.filter_field_white_ex(obj, fields)
    if not obj or not fields then
        return
    end
    local filters = {}
    for k, v in pairs(obj) do
        if not fields[k] then
            filters[k] = v
            obj[k] = nil
        end
    end
    return filters
end

-- 根据黑名单过滤对象。(黑名单中的属性将被过滤掉)
-- fields 格式为：{field1=true, field2=true}
function _M.filter_field_black(obj, fields)
    if not obj or not fields then
        return
    end
    for k,_ in pairs(fields) do
        obj[k] = nil
    end
end

-- 根据黑名单过滤对象并返回。(黑名单中的属性将被过滤掉)
-- fields 格式为：{field1=true, field2=true}
function _M.filter_field_black_ex(obj, fields)
    if not obj or not fields then
        return
    end
    local filters = {}
    for k,_ in pairs(fields) do
        filters[k] = obj[k]
        obj[k] = nil
    end
    return filters
end


function _M.list_filter(objs, filter, fargs)
    if not objs then
        return
    end
    if type(objs) == 'table' then
        for _, obj in ipairs(objs) do
            filter(obj, fargs)
        end
    else
        ngx.log(ngx.ERR, "objs not a list, type:", type(objs), " value:", tostring(objs))
    end
end

function _M.modify_field(objs, fields, info_field, filterfunc)
    if filterfunc then
        local filters = filterfunc(objs, fields)
        objs[info_field] = filters
    end
end

function _M.modify_in_field(objs, filter_field, fields, info_field, filterfunc)
    if objs and objs.filter_field and filterfunc then
        local filters = filterfunc(objs.filter_field, fields)
        objs[info_field] = filters
    end
end

function _M.list_filter_in_field(objs, filter, field, fargs)
    if type(objs) == 'table' then
        for _, obj in ipairs(objs) do
            if obj[field] then
                filter(obj[field], fargs)
            end
        end
    else
        ngx.log(ngx.ERR, "objs not a list, type:", type(objs), " value:", tostring(objs))
    end
end

function _M.encrypt_id(id, base64_key)
  local base64_id = base64.encode_base64(id, false)
  local encrypt_id = string.sub(base64_id, 1, 3).. base64_key..string.sub(base64_id, 4, string.len(base64_id))
  encrypt_id = string.reverse(encrypt_id);
  return base64.encode_base64(encrypt_id, false)
end

function _M.encrypt_share_url(id, url, type, base64_key)
  local base64_id = _M.encrypt_id(id, base64_key)
  return url .."/" .. type .. "?id=".. base64_id
end

function _M.sort_by_array(objs, field_name, ids)
    if type(objs) ~= 'table' then
        return objs
    end
    local ids_map = {}
    for i, value in ipairs(ids) do
        ids_map[tostring(value)] = i
    end
    local json = require("core.json")
    local x = 1000
    table.sort(objs, function(a, b)
        local a_val = x
        local b_val = x
        if a and type(a) == 'table' then
            local a_key = a[field_name] or 0
            a_val = ids_map[tostring(a_key)] or x
        end

        if b and type(b) == 'table' then
            local b_key = b[field_name] or 0
            b_val = ids_map[tostring(b_key)] or x
        end
        x = x + 1
        return a_val < b_val
    end)
    return objs
end

function _M.sort_by_array_reverse(objs, field_name, ids)
    if type(objs) ~= 'table' then
        return objs
    end
    local ids_map = {}
    for i, value in ipairs(ids) do
        ids_map[tostring(value)] = i
    end
    local json = require("core.json")
    local x = 1000
    table.sort(objs, function(a, b)
        local a_val = x
        local b_val = x
        if a and type(a) == 'table' then
            local a_key = a[field_name] or 0
            a_val = ids_map[tostring(a_key)] or x
        end

        if b and type(b) == 'table' then
            local b_key = b[field_name] or 0
            b_val = ids_map[tostring(b_key)] or x
        end
        x = x + 1
        return a_val > b_val
    end)
    return objs
end

local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
--[[
querys format:
querys = {
    {callback, args...},
    {callback2, args...},
}
callback只能是返回 ok, object
]]
function _M.thread_query(querys)
  local threads = {}
  for _, queryargs in ipairs(querys) do
    local callback = queryargs[1]
    local n = #queryargs
    table.remove(queryargs,1)
    local thread = spawn(callback, unpack(queryargs, 1, n-1))
    table.insert(threads, thread)
  end

  local results = {}
  for i = 1, #threads do
    local wok, ok, result = wait(threads[i])
    if not wok or not ok then
        ngx.log(ngx.ERR, "wait thread failed! ok: ", tostring(ok), " result: ", tostring(result))
        return false, 'ERR_SERVER_ERROR'
    end

    if result ~= nil then
      results[i] = result
    end
  end
  return true, results
end

function _M.get_ip()
    local headers = ngx.req.get_headers()
    local ip = headers["x-forwarded-for"]
    if ip == nil then
        ip = headers["x-real-ip"]
    end
    if ip == nil then
        ip = ngx.var.remote_addr
    end

    if type(ip) == 'table' then
        ip = ip[#ip]
    end

    return ip, ngx.var.country_code, ngx.var.city_name
end

--[[
解决tonumber参数为nan时，业务层出错的问题
]]--
function _M.tonumber(v)
    if v == nil then
        return nil
    end

    local t = tonumber(v)

    if t == nil then
        return nil
    end

    if string.lower(v) == "nan" then
        return nil
    end

    return t
end

--[[
统计字符串，英文数字占1个字节，其它占2个字节
]]--
function _M.char_count(v)
    local len = #v
    local width = 0
    local i = 1

    while (i <= len) do
        local cur_byte = string.byte(v, i)
        local byte_count = 1;
        if cur_byte >0 and cur_byte <= 127 then
            byte_count = 1
        elseif cur_byte >= 192 and cur_byte < 223 then
            byte_count = 2
        elseif cur_byte >= 224 and cur_byte < 239 then
            byte_count = 2
        elseif cur_byte >= 240 and cur_byte <= 247 then
            byte_count = 2
        end

        i = i + byte_count
        width = width + 1
    end

    return width
end

--[[
去字符串左右空格
]]--
function _M.str_trim(s)
    if type(s) ~= "string" then
        return s
    end

    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

--[[
字符串分割
]]--
function _M.str_split(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end

function _M.get_sql_where_str(obj)
    local str = ""
    if not obj then
        return str
    end
    local sql_table = {}
    for k, v in pairs(obj) do
        if type(v) ~= 'table' then
            local sql
            if type(cv) == 'string' then
                sql = "`"..tostring(k).."`="..ngx.quote_sql_str(v)
            else
                sql = "`"..tostring(k).."`="..tostring(v)
            end
            
            table.insert(sql_table, sql)          
        end
    end

    if next(sql_table) then
        str = "where " .. table.concat(sql_table, " and ")
    end
    return str
end

-- 在区间下标内随机获取count个不同的下标
function _M.get_random_count(min, max, count)
    local random_index = {}
    local total = max-min+1
    if total <= count then
        for i=min, max, 1 do 
            table.insert(random_index, i)
        end
    else
        local num = total-count
        if num < count then     --随机数多用排除法
            local exclude = {}
            local size = 0
            while size<num 
            do
                local index =math.random(min, max)
                if not exclude[tostring(index)] then
                    exclude[tostring(index)] = index
                    size = size+1
                end
            end
            for i=min, max, 1 do
                if not exclude[tostring(i)] then
                    table.insert(random_index, i)
                end
            end
        else

            local include = {}
            local size = 0
            while size<count 
            do
                local index =math.random(min, max)
                if not include[tostring(index)] then
                    include[tostring(index)] = index
                    size = size+1
                end
            end 
            for _, v in pairs(include) do
                table.insert(random_index, v)
            end       
        end
    end
    return random_index
end

function _M.get_cache_key(...)
    local arg = { ... }
    local key = table.concat(arg, "-")
    return key
end

return _M
