local cjson = require "cjson"
local config = ngx.shared.config;
local commands = ngx.shared.commands;

config:flush_all()

local file = io.open("PATH/TO/weixin/config/conf.json", "r");
local content = cjson.decode(file:read("*all"));
file.close(file);

for k, v in pairs(content) do
    config:set(k, v)
end
