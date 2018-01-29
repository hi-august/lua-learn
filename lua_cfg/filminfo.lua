local _M = {}

_M.mongo_cfg = {
    host = "127.0.0.1",
	port = 27017,
	dbname = "filminfo",
	timeout = 1000*15,
}

return _M
