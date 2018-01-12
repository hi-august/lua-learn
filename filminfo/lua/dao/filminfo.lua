local mongo_dao = require("resty.mgo.mongo_dao")
local mongo_dao_cache = require("resty.mgo.mongo_dao_cache")
local util = require("core.util")
local json = require("core.json")
local config = require("config")

local _M = {}

local mt = { __index = _M }

-- 搜索(列表)接口返回的字段列表
local find_fields = {
    _id = false, --_id返回的是一个函数,dumps会出错,需过滤
    fid = true,
    doubanid = true,
    name = true,
    short_title = true,
    alias = true,
    desc = true,
    category = true,
    type = true,
    tag = true,
    director = true,
    actor = true,
    pubdate = true,
    area = true,
    pingfen = true,
    imdb_rating = true,
    tom_critics = true,
    tom_audience = true,
    language = true,
    episodes = true,
    scriptwriter = true,
    cover_image = true,
    video_status = true,
    flag=true,
    images_phone=true,
    images_web=true,
    recommend = true
}

_M.find_fields = find_fields
_M.add_fields = find_fields
_M.list_fields = find_fields

function _M:new(mongo_cfg)
    assert(mongo_cfg ~= nil)
    local collname = "filminfo"
    local id_field = "fid"

    -- local metainfo = {
        -- id_field = id_field,
    -- }
	-- local obj = mongo_dao:new(mongo_cfg, collname, metainfo)
    -- return obj:extends(_M)

    local cachename = "filminfo"
    local cache_prefix = "f:"
    local cache_exptime = config.filminfo_exptime or 300

    local args = {
        list_fields = _M.list_fields,
        detail_fields = _M.detail_fields,
        cachename = cachename,
        cache_prefix = cache_prefix,
        cache_exptime = cache_exptime,
        stats_shm_name = "cachestats",
        stats_prefix = collname,
    }
    local obj = mongo_dao_cache:new(mongo_cfg, collname, id_field, args)

    return obj:extends(_M)
end

-- 查找shm缓存,没有找到再查找mongo
function _M:get_by_id(fid, fields)
	local ok, obj = self.supers[_M].get_by_id(self, fid, fields)
    if not ok then
        ngx.log(ngx.ERR, "get_by_id (", tostring(fid), ") failed! not found")
    end
	return ok, obj
end

local function __FILE__()
    return debug.getinfo(2, "S").short_src
end

_M.src_name = __FILE__()
local hook = require("core.hook")
hook.hook_dao(_M, { new = true, extends = true, init = true, uninit = true })

return _M
