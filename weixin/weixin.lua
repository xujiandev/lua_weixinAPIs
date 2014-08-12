local client = require "client"

local weixin_client = client:new()

local val, err = weixin_client:get('test', { grant_type = 'client_credential', access_token = true })

ngx.say(val)
ngx.say(err)
