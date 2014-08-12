
local setmetatable = setmetatable
local config = ngx.shared.config
local ngx = ngx
local tinsert = table.insert
local tconcat = table.concat
local pairs = pairs
local cjson = require "cjson"
local type = type
local resty_lock = require "resty.lock"

local _M = {}
_M._VERSION = '0.1'

local weixin_errcode = {
	[-1] = '系统繁忙',
	[40001] = '获取access_token时AppSecret错误，或者access_token无效',
	[40002] = '不合法的凭证类型',
	[40003] = '不合法的OpenID',
	[40004] = '不合法的媒体文件类型',
	[40005] = '不合法的文件类型',
	[40006] = '不合法的文件大小',
	[40007] = '不合法的媒体文件id',
	[40008] = '不合法的消息类型',
	[40009] = '不合法的图片文件大小',
	[40010] = '不合法的语音文件大小',
	[40011] = '不合法的视频文件大小',
	[40012] = '不合法的缩略图文件大小',
	[40013] = '不合法的APPID',
	[40014] = '不合法的access_token',
	[40015] = '不合法的菜单类型',
	[40016] = '不合法的按钮个数',
	[40017] = '不合法的按钮个数',
	[40018] = '不合法的按钮名字长度',
	[40019] = '不合法的按钮KEY长度',
	[40020] = '不合法的按钮URL长度',
	[40021] = '不合法的菜单版本号',
	[40022] = '不合法的子菜单级数',
	[40023] = '不合法的子菜单按钮个数',
	[40024] = '不合法的子菜单按钮类型',
	[40025] = '不合法的子菜单按钮名字长度',
	[40026] = '不合法的子菜单按钮KEY长度',
	[40027] = '不合法的子菜单按钮URL长度',
	[40028] = '不合法的自定义菜单使用用户',
	[40029] = '不合法的oauth_code',
	[40030] = '不合法的refresh_token',
	[40031] = '不合法的openid列表',
	[40032] = '不合法的openid列表长度',
	[40033] = '不合法的请求字符，不能包含\\uxxxx格式的字符',
	[40035] = '不合法的参数',
	[40038] = '不合法的请求格式',
	[40039] = '不合法的URL长度',
	[40050] = '不合法的分组id',
	[40051] = '分组名字不合法',
	[41001] = '缺少access_token参数',
	[41002] = '缺少appid参数',
	[41003] = '缺少refresh_token参数',
	[41004] = '缺少secret参数',
	[41005] = '缺少多媒体文件数据',
	[41006] = '缺少media_id参数',
	[41007] = '缺少子菜单数据',
	[41008] = '缺少oauthcode',
	[41009] = '缺少openid',
	[42001] = 'access_token超时',
	[42002] = 'refresh_token超时',
	[42003] = 'oauth_code超时',
	[43001] = '需要GET请求',
	[43002] = '需要POST请求',
	[43003] = '需要HTTPS请求',
	[43004] = '需要接收者关注',
	[43005] = '需要好友关系',
	[44001] = '多媒体文件为空',
	[44002] = 'POST的数据包为空',
	[44003] = '图文消息内容为空',
	[44004] = '文本消息内容为空',
	[45001] = '多媒体文件大小超过限制',
	[45002] = '消息内容超过限制',
	[45003] = '标题字段超过限制',
	[45004] = '描述字段超过限制',
	[45005] = '链接字段超过限制',
	[45006] = '图片链接字段超过限制',
	[45007] = '语音播放时间超过限制',
	[45008] = '图文消息超过限制',
	[45009] = '接口调用超过限制',
	[45010] = '创建菜单个数超过限制',
	[45015] = '回复时间超过限制',
	[45016] = '系统分组，不允许修改',
	[45017] = '分组名字过长',
	[45018] = '分组数量超过上限',
	[46001] = '不存在媒体数据',
	[46002] = '不存在的菜单版本',
	[46003] = '不存在的菜单数据',
	[46004] = '不存在的用户',
	[47001] = '解析JSON/XML内容错误',
	[48001] = 'api功能未授权',
	[50001] = '用户未授权该api'
}

local mt = { __index = _M }

function _M.new(self)
	local appid, secret, tokenkey = config:get("appid"), config:get("secret"), config:get("tokenkey")
	if not appid or not secret or not tokenkey then
		ngx.log(ngx.ERR, "init client with appid: ", appid, " and secret ", secret, " and tokenkey ", tokenkey)
		return nil, "init error"
	end
    return setmetatable({ appid = appid, secret = secret, tokenkey = tokenkey }, mt)
end

local function build_query(self, param)
	if type(param) ~= 'table' then
		return nil
	end
	local params = {}
	for k, v in pairs(param) do
		tinsert(params, tconcat({ k, v }, "="))
	end
	return tconcat(params, "&")
end

--optoken
local function fetch_optoken(self)

	local token, err = config:get(self.tokenkey)
	if token then
		return token, nil
	end

    --mylock is the shared_dict defined in the nginx config file
	local lock, err = resty_lock:new("mylock", { exptime = 10, timeout = 8, max_step = 0.1 })
	local elapsed, err = lock:lock(self.tokenkey)
	if not elapsed then
		ngx.log(ngx.ERR, "fail to acquire the lock: ", err)
		return nil, "fail to acquire the lock " .. err
	end
    --check again
	token, err = config:get(self.tokenkey)
	if token then
		local ok, err = lock:unlock()
		if not ok then
			ngx.log(ngx.ERR, "fail to unlock after hit cache second time: ", err)
			return nil, "fail to unlock: " .. err
		end
		return token, nil
	end

    --remote require
	local val, err = self:get('cgi-bin/token', { grant_type = 'client_credential', appid = true, secret = true })
    if not err then
        token = val.access_token
        local ttl = val.expires_in

        --set cache
        local ok, err = config:set(self.tokenkey, token, ttl - 200)
        if not ok then
            ngx.log(ngx.ERR, "fail to set ", self.tokenkey, " ", token)
            local ok2, err2 = lock:unlock()
            if not ok2 then
                return nil, "fail to set cache and unlock"
            end
            return nil, "fail to set cache"
        end
    end

	--unlock
	local ok, err = lock:unlock()
	if not ok then
		ngx.log(ngx.ERR, "fail to unlock after set cache")
	end

	return token, nil

end

local function replace_key(self, param)
	for k, mark in pairs(param) do
        if mark then
            if k == 'appid' then
                param[k] = self.appid
            elseif k == 'secret' then
                param[k] = self.secret
            elseif k == 'access_token' then
                local token = fetch_optoken(self)
                param[k] = token
            end
        end
	end
	return param
end

local function analyze(self, ret)
	local rstatus = ret.status
	local rheader = ret.rheader
	local rbody = ret.body
	if rstatus ~= ngx.HTTP_OK then
		ngx.log(ngx.ERR, 'connect weixin error with: ', rstatus)
		return nil, 'connect weixin error with http code ' .. rstatus
	end
	rbody = cjson.decode(rbody)
	if rbody.errcode and 0 ~= rbody.errcode then
		local errmsg = rbody.errmsg or ''
		if weixin_errcode[rbody.errcode] then
			errmsg = errmsg .. "," .. weixin_errorcode[rbody.errcode]
		end
		ngx.log(ngx.ERR, errmsg)
		return nil, errmsg
	end
	return rbody, nil
end

local function set_header(self, header)
	if not header then
		return
	end
	for k, v in pairs(header) do
		ngx.req.set_header(k, v)
	end
end

local function request(self, ...)
	local args = { ... }
	local method = args[1]
	local url = args[2]
	local url_param = args[3] or {}
	local post_param = args[4] or {}
	local opts = args[5] or {}

	local url = '/p2weixin/' .. url

	url_param = replace_key(self, url_param)
	if type(post_param) == 'table' then
		post_param = build_query(replace_key(self, post_param))
	end

	local request_param = {}
	request_param.method = method
	if url_param then request_param.args = url_param end
	if post_param then request_param.body = post_param end

	--opts.header
	if opts.header then set_header(self, opts.header) end

	local ret = ngx.location.capture(
		url, request_param
	)

	return analyze(self, ret)
end

function _M.get(self, ...)
	local args = { ... }
	local url = args[1] or nil
	if not url then
		ngx.log(ngx.ERR, "get error with args: ", ...)
		return nil, 'get params error'
	end
	return request(self, ngx.HTTP_GET, ...)
end

function _M.post(self, ...)
	local args = { ... }
	local url = args[1] or nil
	local post_params = args[3] or nil
	if not url or not post_params then
		ngx.log(ngx.ERR, "post error with args: ", ...)
		return nil, 'post params error'
	end
	return request(self, ngx.HTTP_POST, ...)
end

return _M
