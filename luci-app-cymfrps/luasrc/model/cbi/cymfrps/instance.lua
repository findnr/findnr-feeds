local m = Map("cymfrps", translate("Edit Instance"), translate("Configure FRPS server instance details."))
m.redirect = luci.dispatcher.build_url("admin", "services", "cymfrps")

local s = m:section(NamedSection, arg[1], "instance", "")

local o

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false

o = s:option(ListValue, "type", translate("Config Format"))
o:value("ini", "INI")
o:value("toml", "TOML")
o:value("yaml", "YAML")
o:value("json", "JSON")
o.default = "ini"

o = s:option(TextValue, "content", translate("Config Content"))
o.rows = 20
o.wrap = "off"
o.description = translate("Paste raw config content here, make sure the format is correct.")
o.rmempty = false

return m
