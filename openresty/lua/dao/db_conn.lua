local config = require("config")

local _M = {}

local filminfocrawldao = require("dao.filminfo")

_M.filminfo_dao = function()
    return filminfocrawldao:new(config.mongo_cfg)
end

return _M
