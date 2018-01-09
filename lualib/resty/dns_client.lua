
local resolver = require "resty.dns.resolver"

local _M = {}

_M.nameservers = nil
_M.strnameservers = nil


local function trim (s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

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
    if nb == maxNb-1 and lastPos < #str+1 then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
end

function _M.is_ip(strip)
    if strip == nil or strip == "" then
        return false
    end
    return string.match(strip, "^%d+.%d+.%d+.%d+") ~= nil
end

local function readresolv(filename)
    local rfile=io.open(filename, "r") --读取文件(r读取)
    if not rfile then
        return nil
    end
    local resolvs = {}
    for str in rfile:lines() do     --一行一行的读取
        str = trim(str)
        ngx.log(ngx.INFO, "str:", str)
        local len = string.len(str)
       if len > 10 and string.sub(str,1,1) ~= '#' then
            local sarr = _M.split(str, ' \t')
            if table.getn(sarr) == 2 and sarr[1] == "nameserver" then
                --print("nameserver:", sarr[2])
                table.insert(resolvs, sarr[2])
            end
       end
    end
    rfile:close()
    return resolvs
end

function _M.dns_init()
    --ngx.log(nxg.INFO, "############# dns_init ##############")
    local resolv_file = "/etc/resolv.conf"
       
    ngx.log(ngx.INFO, "init dns from resolv_file:", resolv_file)
    local dns_svr = {"8.8.8.8"}
    local resolvs = readresolv(resolv_file)
    if resolvs then
        dns_svr = resolvs
    end

    if type(dns_svr) == 'table' then
        for i,nameserver in ipairs(dns_svr) do
            ngx.log(ngx.INFO, "nameserver: ", nameserver)
        end
    else
        ngx.log(ngx.INFO, "nameserver: ", dns_svr)
    end

    _M.nameservers = {}
    _M.strnameservers = {}

    if dns_svr then
        local dns_svrs = nil
        if type(dns_svr) == 'table' then
            dns_svrs = dns_svr
        else
            dns_svrs = {dns_svr}
        end
        for i,dns_svr in ipairs(dns_svrs) do
            local dnsarr = _M.split(dns_svr, ':')
            if table.getn(dnsarr) == 2 then
                local dns_host = dnsarr[1]
                local dns_port = tonumber(dnsarr[2]) or 53
                table.insert(_M.nameservers, {dns_host, dns_port})
            else
                table.insert(_M.nameservers, dns_svr)
            end
            table.insert(_M.strnameservers, dns_svr)
            --ngx.log(ngx.INFO, "DNS:", dns_svr)
        end        
    else
        table.insert(_M.nameservers, "8.8.8.8")
        table.insert(_M.nameservers, {"8.8.4.4", 53})
        table.insert(_M.strnameservers, "8.8.8.8")
        table.insert(_M.strnameservers, "8.8.8.4:53")
    end
end

function _M.dns_query(domain)
    local dns_key = "dns:" .. domain 
    local cache = ngx.shared.cache
    if cache then
        local v = cache:get(dns_key)
        if v then
            ngx.log(ngx.INFO, "resolver [", domain, "] from cache! address:", v)
            return v
        end
    end

    
    local answers = nil
    local err = nil
    local dns_query_timeout = dns_query_timeout or 5000
    --依次从多个DNS服务器上查询域名。
    for i, nameserver in ipairs(_M.nameservers) do
        local strnameserver = _M.strnameservers[i]

        local cur_nameservers = {nameserver}
        ngx.log(ngx.INFO, "######### resolve [",domain,"] from:[", strnameserver, "]")

        local r, err = resolver:new{
            nameservers = cur_nameservers,
            retrans = 3,  -- 5 retransmissions on receive timeout
            timeout = dns_query_timeout,  -- 2 sec
        }
       
        if not r then
            ngx.log(ngx.ERR, "failed to instantiate the dns resolver: ", err)
        else 

            r:set_timeout(dns_query_timeout)
            answers, err= r:query(domain)
            if answers and not answers.errcode and table.getn(answers) > 0 then
                -- 成功了。
                ngx.log(ngx.INFO, "........... answers:", table.getn(answers))
                break 
            end

            if answers then
                if answers.errcode then
                    ngx.log(ngx.ERR, "dns server returned error code: ", answers.errcode,":", answers.errstr)
                elseif table.getn(answers)==0 then
                    ngx.log(ngx.ERR, "dns server returned zero item from: ", strnameserver)
                end
            else
                ngx.log(ngx.ERR, "failed to query the DNS server: ", err)
            end           
        end
    end
    if not answers then
        return nil
    end

    local addrs = {}

    for i, ans in ipairs(answers) do
        ngx.log(ngx.INFO, "dns_resp:", ans.name, " ", ans.address or ans.cname,
                " type:", ans.type, " class:", ans.class,
                " ttl:", ans.ttl)
        if ans.address then
            table.insert(addrs, ans)
        end
    end

    local n = table.getn(addrs)
    if n == 0 then
        ngx.log(ngx.ERR, string.format("no valid ip in the dns response!"))
        return nil
    end
    n = math.random(n)
    local addr = addrs[n]
    if not _M.is_ip(addr.address) then
        ngx.log(ngx.ERR, string.format("invalid ip [%s] from the dns response!", addr.address))
        return nil
    end
    
    ngx.log(ngx.INFO, "dns query:{domain:",domain, ", address:", addr.address, ", ttl:", addr.ttl, "}")

    if addr.ttl == 0 then
        addr.ttl = 60*5
    end
    if cache then
        ngx.log(ngx.INFO, "set dns cache(", dns_key, ",", addr.address, ",", addr.ttl, ")...")
        cache:set(dns_key, addr.address, addr.ttl)
    end

    return addr.address
end

-- 尝试从/etc/resolv.conf读取dns配置(如果有配置)。
_M.dns_init()

return _M