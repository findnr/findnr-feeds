local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"

local m = Map("cymfrpc", translate("CymFrpc Client"), translate("Manage multiple FRPC instances with raw config support."))

local s = m:section(TypedSection, "instance", translate("Instance List"))
s.template = "cbi/tblsection"
s.addremove = true
s.extedit = luci.dispatcher.build_url("admin", "services", "cymfrpc", "instance", "%s")

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
	local pid = sys.exec("pgrep -f '/var/etc/cymfrpc/" .. section .. "\\.'")
	if pid and #pid > 0 then
		return string.format("<span style=\"color:green; font-weight:bold\">%s (PID %s)</span>", translate("Running"), pid:gsub("\n", ""))
	else
		return string.format("<span style=\"color:red\">%s</span>", translate("Stopped"))
	end
end

o = s:option(Value, "type", translate("Config Format"))
o.readonly = true

return m
