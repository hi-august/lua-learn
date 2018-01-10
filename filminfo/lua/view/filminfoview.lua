local json = require("core.json")
local util = require("core.util")
local apierror = require("view.apierror")
local viewutil = require("core.viewutil")
local viewpub = require("view.viewpub")

local list_fields = viewpub.filminfo_dao().list_fields

local function filminfo_list()
    local args = ngx.req.get_uri_args()
    local values = {}

    values.create_start_time = tonumber(args.create_start_time) or 0
    values.create_end_time = tonumber(args.create_end_time) or 0
    values.update_start_time = tonumber(args.update_start_time) or 0
    values.update_end_time = tonumber(args.update_end_time) or 0
    values.category = tonumber(args.category)
    values.fid = tonumber(args.fid)
    values.doubanid = tonumber(args.doubanid)
    values.name = args.name
    values.original_name = args.original_name or ""
    values.imdb = args.imdb
    values.updator_name = args.updator_name
    values.show_status= tonumber(args.show_status) or nil
    values.img_status= tonumber(args.img_status) or nil
    values.source_type = args.source_type or 'douban'
    values.crawl_type = tonumber(args.crawl_type) or nil

    local page = tonumber(args.page) or 1
    if page < 1 then
        page = 1
    end
    local limit = tonumber(args.page_size) or 10
    local skip = (page - 1) * limit
    local selector = {}

    if values.create_start_time and values.create_end_time and values.create_start_time > 0 and values.create_end_time > 0 then
        selector.create_time = { ['$gte'] = values.create_start_time, ['$lte'] = values.create_end_time }
    end
    if values.update_start_time and values.update_end_time and values.update_start_time > 0 and values.update_end_time > 0 then
        selector.update_time = { ['$gte'] = values.update_start_time, ['$lte'] = values.update_end_time }
    end
    if values.category and values.category > 0 then
        selector.category = values.category
    end
    if values.updator_name and values.updator_name ~= "" then
        selector.updator_name = values.updator_name
    end
    if values.name and values.name ~= "" then
        selector.name = values.name
    end
    if values.imdb and values.imdb ~= '' then
        selector.imdb = values.imdb
    end
    if values.original_name and values.original_name ~= '' then
        selector.name_alias = values.name_alias
    end
    if values.show_status ~= nil then
        selector.show_status = values.show_status
    end
    if values.img_status ~= nil then
        selector.img_status = values.img_status
    end
    if values.crawl_type ~= nil then
        selector.crawl_type = values.crawl_type
    end
    -- 待审核状态为2和4, 2为没有图片, 4为爬取完成
    -- selector.status = { ["$in"] = { 2,4 } }
    selector.is_delete = 0
    -- _id是一个函数,需过滤,否则dumps报错
    local films = {}
    local ok, count
    if values.source_type == 'douban' then
        local sortby = { create_time = -1 }
        if values.fid and values.fid > 0 then
            selector.fid = values.fid
        end
        if values.doubanid and values.doubanid > 0 then
            selector.doubanid = values.doubanid
        end
        ok, films = viewpub.filminfo_dao():find(selector, list_fields, sortby, skip, limit)
        if not ok then
            return json.ok({ films = {}, list_ended = true, total = 0 })
        end
        ok, count = viewpub.filminfo_dao():count(selector)
        for _, v in pairs(films) do
            v.source_type = 'douban'
        end
    else
        ngx.log(ngx.ERR, 'source_type err: ', values.source_type)
        return json.fail(apierror.ERR_ARGS_INVALID)
    end
    if not ok then
        return json.ok({ films = {}, list_ended = true, total = count })
    end
    local ended = true
    if films and #films > 0 and #films == limit then
        ended = false
    end
    return json.ok({ films = films, list_ended = ended, total = count })
end

local function filminfo_detail()
    local args = ngx.req.get_uri_args()
    local doubanid = tonumber(args.doubanid) or 0
    local source_type = args.source_type or 'douban'
    local ok, filminfo, films = nil, {}, {}
    if source_type == 'douban' then
        local selector = { doubanid=doubanid }
        list_fields.pubdate_m = true
        ok, filminfo = viewpub.filminfo_dao():find_one(selector, list_fields)
        if not ok or not filminfo then
            ngx.log(ngx.ERR, "get filminfo_dao douban (", tostring(doubanid), ") failed! not found")
            return json.fail(apierror.ERR_OBJECT_NOT_FOUND)
        end
        filminfo.source_type = 'douban'
        local selector = { fid=filminfo.fid }
        -- 查询filminfo中的preaudit状态.
        local ok, filminfo_target = viewpub.filminfo_dao():find_one(selector)
        if ok and filminfo_target then
            filminfo.preaudit = filminfo_target.preaudit
        end
        local fields = { fid=true, doubanid=true, name=true, category=true, original_name=true, short_title=true, mfid_db=true, mid_db=true, preaudit=true, pub_status=true, stills=true, poster=true }
        local sortby = { fid = -1 }
        local films = {}
        local ok
        if filminfo.fids and type(filminfo.fids) == 'table' and not util.table_is_empty(filminfo.fids) then
            local selector = {}
            selector.fid = { ["$in"]=filminfo.fids }
            ok, films = viewpub.filminfo_dao():find(selector, fields, sortby)
        end
        filminfo.relate_films = films
    else
        ngx.log(ngx.ERR, 'source_type err: ', source_type)
        return json.fail(apierror.ERR_ARGS_INVALID)
    end
    return json.ok(filminfo)
end

local function filminfo_upsert()
    ngx.req.read_body()
    local json_str = ngx.req.get_body_data()
    local args = viewutil.check_post_json(json_str)
    local status =  tonumber(args.status) or 0
    local pingfen =  tonumber(args.pingfen) or nil
    local doubanid =  tonumber(args.doubanid) or 0
    if doubanid < 1 then
        return json.fail(apierror.ERR_ARGS_INVALID)
    end
    local selector = { doubanid=doubanid }
    local update = {}
    if status > 0 then
        update.status = status
    end
    if pingfen then
        update.pingfen = pingfen
    end
    local updater = { ['$set']=update }
    -- 不存在插入
    -- local ok, err = viewpub.filminfo_dao():upsert(selector, updater, 1, true)
    local ok, err = viewpub.filminfo_dao():upsert(selector, updater, 0, true)
    if not ok then
        ngx.log(ngx.ERR, "filminfo_dao upsert(", json.dumps(selector), ",", json.dumps(updater), ") failed! err:", tostring(err))
        return json.fail(apierror.ERR_SERVER_ERROR)
    end
    return json.ok()
end

local function filminfo_delete()
    ngx.req.read_body()
    local json_str = ngx.req.get_body_data()
    local args = viewutil.check_post_json(json_str)
    local source_type =  args.source_type or 'douban'
    local headers = ngx.req.get_headers()
    local updator = tonumber(headers["x-userid"]) or 0
    local updator_name = ngx.unescape_uri(headers["x-nickname"]) or "system"
    local fields = {}
    local selector = {}
    fields = { doubanid=true, is_delete="number", source_type=true }
    local err = util.check_fields(args, fields)
    local doubanid = tonumber(args.doubanid) or 0
    if err ~= nil or doubanid < 1 then
        return json.fail(apierror.ERR_ARGS_INVALID)
    end
    local updater = { ["$set"] = { update_time=ngx.time(), is_delete=1 }}
    local selector = { doubanid=doubanid }
    local ok, err = viewpub.filminfo_dao():delete(selector)
    if not ok then
        ngx.log(ngx.ERR, "filminfo_dao delete(", json.dumps(selector))
        return json.fail(apierror.ERR_SERVER_ERROR)
    end
    return json.ok()
end

local router = {
    -- curl 127.0.0.1:8100/filminfo/list
    ["/filminfo/list"] = filminfo_list,
    -- curl 127.0.0.1:8100/filminfo/detail?doubanid=1757196
    ["/filminfo/detail"] = filminfo_detail,
    -- curl '127.0.0.1:8100/filminfo/upsert' -d '{"doubanid": 321480777, "status": 10, "pingfen": 7.7}'
    ["/filminfo/upsert"] = filminfo_upsert,
    -- curl '127.0.0.1:8100/filminfo/delete' -d '{"doubanid": 321480777}'
    ["/filminfo/delete"] = filminfo_delete,
}

local uri = ngx.var.uri
ngx.header['Content-Type'] = "application/json;charset=UTF-8"

if router[uri] then
    local resp = router[uri]()
    if resp then
        if type(resp) == 'table' then
            resp = json.dumps(resp)
        end
        ngx.say(resp)
    end
else
    ngx.log(ngx.ERR, "invalid request [", uri, "]")
    ngx.exit(404)
end
