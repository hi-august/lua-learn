
local _M = {}


local encode_rep_tab = {['/']='_', ['+']='-'}
local decode_rep_tab = {['_']='/', ['-']='+'}

local encode_replace = function (m)
     return encode_rep_tab[m[0]] or ''
end
local decode_replace = function (m)
     return decode_rep_tab[m[0]] or ''
end

function _M.encode_base64(str, no_padding)
	str = ngx.encode_base64(str, no_padding)
	local newstr, n, err = ngx.re.gsub(str, "[/+]", encode_replace, "joi")
	return newstr
end 

function _M.decode_base64(str)
	local newstr, n, err = ngx.re.gsub(str, "[-_]", decode_replace, "joi")
	return ngx.decode_base64(newstr)
end

return _M