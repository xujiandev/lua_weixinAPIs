lua_weixinAPIs
==============

基于openresty实现的[weixin api](http://mp.weixin.qq.com/wiki/index.php?title=%E9%A6%96%E9%A1%B5 "weixin")接口。

特点
-----
**锁**：基于lua_restry_lock的锁，在或者access_token时，token失效时多个进程同时去获取，出现冲突。

使用方法
-----------
**修改对应路径 **  
修改nginx.conf, init.lua 中的对应路径

**修改server信息 **  
修改nginx.conf中的server_name, port等信息

**修改配置**  
修改config/conf.json里的配置信息，填入从微信申请到了appid和secret，tokenkey为要放到ngx.shared.dict里的access_token的名称。

**启动**  
启动nginx即可

方法
====
```lua
local client = require "client"
```
new
---
`syntax: weixin_client, err = client:new()`
创建client实例

get
---
`syntax:  local ret, err = weixin_client:get(url, {p1=v1, p2=v2})`

发送HTTP_GET的请求，形如：

>'curl https://weixinHOST/url?p1=v1&p2=v2'

其中，如果参数里需要appid，secret，access_token，直接将这个字段赋值为ture即可，如{appid = ture, secret = true, access_token = true, p1 = v1}

post
---
`syntax:  local ret, err = weixin_client:post(url, {p1=v1, p2=v2},  body)`

发送HTTP_POST请求，{p1=v1, p2=v2}同get方法，body可以为table或者字符串，如果为table会转换成k1=v1&k2=v2的形式，
形如: 

>'curl https://weixinHOST/url?access_token=123 -d "k1=v1&kv=v2"'

>'curl https://weixinHOST/url?access_token=123 -d "{"k1":"v1", "k2":"v2"}"'

TODO
=====
对于json或者xml的自动生成

