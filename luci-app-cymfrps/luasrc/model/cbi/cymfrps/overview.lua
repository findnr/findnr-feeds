local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"

local m = Map("cymfrps", translate("CymFrps Server"), translate("Manage multiple FRPS server instances with raw config support."))

local s = m:section(TypedSection, "instance", translate("Instance List"))
s.template = "cbi/tblsection"
s.addremove = true
s.extedit = luci.dispatcher.build_url("admin", "services", "cymfrps", "instance", "%s")

function s.create(self, name)
	name = name:gsub("[^a-zA-Z0-9_]", "_")
	TypedSection.create(self, name)
	luci.http.redirect(self.extedit % name)
end

local o

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false

o = s:option(DummyValue, "status", translate("Status"))
o.rawhtml = true
function o.cfgvalue(self, section)
	local pid = sys.exec("pgrep -f '/var/etc/cymfrps/" .. section .. "\\.'")
	if pid and #pid > 0 then
		return "<span style=\"color:green; font-weight:bold\">Running (PID " .. pid:gsub("\n", "") .. ")</span>"
	else
		return "<span style=\"color:red\">Stopped</span>"
	end
end

o = s:option(Value, "type", translate("Config Format"))
o.readonly = true

return m
