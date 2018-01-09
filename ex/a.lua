print(package.path)
-- package.path = '/opt/yf-filminfo/lua/?.lua;/opt/yf-filminfo/libs/?.lua;/opt/lua-resty-baselib/libs/?.lua;/opt/lua-resty-baselib/libs/?/init.lua;/opt/lua-resty-stats/lib/?/init.lua;./?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/lib/lua/5.1/?.lua;/usr/local/lib/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua'
-- print(package.path)
-- local http_client = require("resty.http_client")
-- local url = 'https://ms3-gen.test.expressplay.com/hms/ms3/token?errorFormat=json&customerAuthenticator=201325,21b355275dd44eb888d67739275f0507&contentId.0=cid%3Amarlin%23Pnaifei@00000003&contentKey.0=5819fda07bad35459404c53135086cb1&contentURL=http://vodpub.oss-cn-hangzhou.aliyuncs.com/drm/test/17/1080p/16_9/853d/9419/853d9419381e99d26ad727d2781c1f8b.m3u8&expirationTime=2017-09-14T00:25:22Z&ms3Scheme=true&ms3Extension=wudo,false,AAAAAA=='
-- local res, err, debug_str = http_client.http_get(url)
local a = string.format('共计获奖%d次，被提名%d次', 3, 4)
print(a)

local union = function (self, another)
    local set = {}
    local result = {}
    for i, j in pairs(self) do set[j] = true end
    for i, j in pairs(another) do set[j] = true end
    for i, j in pairs(set) do table.insert(result, i) end
    return result
end

-- 没有传递的函数参数为nil
local function get(name, age, test)
    local test = test or 1
    print(name, age, test)
end
local guest = {guest=133719, filmmaker_comment='其实每拍一部电影都是在冰面上行走，我不能保证我一定能走过去，但是站那待着肯定是不行的。', guest_images={}, a=3}
local guests = {guest}
-- get('augst', 22, guests)

local items = {a=1, b=2, c=3}
for k, v in pairs(items) do
    if guest[k] == nil then
        guest[k] = v
    end
end

local mfid_dbs = {1, 2, 3, 4, 5}
local mfid_db = 7
-- table.insert(mfid_dbs, 1, mfid_db)
local updater = { mfid_db }
-- mfid_dbs = union(mfid_dbs, mfid_dbs)
local m = {}
for _, v in pairs(mfid_dbs) do
    if mfid_db ~= v then
        table.insert(m, v)
    end
end

table.insert(m, 1, mfid_db)

for k, v in pairs(m) do
    print(v)
end

local t = '01:30:37'


