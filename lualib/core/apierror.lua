
local _M = {}


-- 服务器内部错误(如访问s3出错了)
_M.ERR_SERVER_ERROR = "ERR_SERVER_ERROR"

-- 签名验证错误。
_M.ERR_SIGN_ERROR = "ERR_SIGN_ERROR"

-- 非法的Token.
_M.ERR_TOKEN_INVALID = "ERR_TOKEN_INVALID"

-- Token已经过期
_M.ERR_TOKEN_EXPIRED = "ERR_TOKEN_EXPIRED"

-- 参数(包括请求参数，请求头字段)错误，缺失
_M.ERR_ARGS_INVALID = "ERR_ARGS_INVALID"

-- 请求查询的对象不存在
_M.ERR_OBJECT_NOT_FOUND = "ERR_OBJECT_NOT_FOUND"

return _M