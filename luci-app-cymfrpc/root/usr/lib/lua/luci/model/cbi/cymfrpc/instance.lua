local m = Map("cymfrpc", translate("编辑实例"), translate("配置 FRPC 实例详情。"))
m.redirect = luci.dispatcher.build_url("admin", "services", "cymfrpc")

local s = m:section(NamedSection, arg[1], "instance", "")

local o

o = s:option(Flag, "enabled", translate("启用"))
o.rmempty = false

o = s:option(ListValue, "type", translate("配置格式"))
o:value("ini", "INI")
o:value("toml", "TOML")
o:value("yaml", "YAML")
o:value("json", "JSON")
o.default = "ini"

o = s:option(TextValue, "content", translate("配置内容"))
o.rows = 20
o.wrap = "off"
o.description = translate("在此粘贴原始配置内容，请确保格式正确。")
o.rmempty = false

return m
