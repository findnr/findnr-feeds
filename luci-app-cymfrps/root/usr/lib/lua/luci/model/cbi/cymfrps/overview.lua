local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"

local m = Map("cymfrps", translate("CymFrps 服务端"), translate("管理多个 FRPS 服务端实例，支持纯文本配置。"))

local s = m:section(TypedSection, "instance", translate("实例列表"))
s.template = "cbi/tblsection"
s.addremove = true
s.extedit = luci.dispatcher.build_url("admin", "services", "cymfrps", "instance", "%s")

function s.create(self, name)
	name = name:gsub("[^a-zA-Z0-9_]", "_")
	TypedSection.create(self, name)
	luci.http.redirect(self.extedit % name)
end

local o

o = s:option(Flag, "enabled", translate("启用"))
o.rmempty = false

o = s:option(DummyValue, "status", translate("状态"))
o.rawhtml = true
function o.cfgvalue(self, section)
	local pid = sys.exec("pgrep -f '/var/etc/cymfrps/" .. section .. "\\.'")
	if pid and #pid > 0 then
		return "<span style=\"color:green; font-weight:bold\">运行中 (PID " .. pid:gsub("\n", "") .. ")</span>"
	else
		return "<span style=\"color:red\">未运行</span>"
	end
end

o = s:option(Value, "type", translate("配置格式"))
o.readonly = true

return m
