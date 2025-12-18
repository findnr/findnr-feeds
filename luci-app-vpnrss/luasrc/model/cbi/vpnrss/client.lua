m = Map("vpnrss", translate("VPN Subscription Aggregator"), translate("Manage your VPN nodes and generate subscription links."))

-- =========================================================================
-- Global Settings
-- =========================================================================
s = m:section(NamedSection, "global", "global", translate("Global Settings"))

o = s:option(Flag, "enabled", translate("Enable Plugin"))
o.rmempty = false

o = s:option(Value, "token", translate("Security Token"), 
	translate("Set a token to protect your subscription link from scanning (recommended).") .. 
	"<br/><button class=\"cbi-button cbi-button-neutral\" type=\"button\" onclick=\"return vpnrss_generate_uuid('cbid.vpnrss.global.token')\">" .. 
	translate("Generate Random Token (UUID)") .. "</button>")
o.rmempty = false

-- Embed the status/links view (includes UUID generator script)
s:append(Template("vpnrss/status"))

-- =========================================================================
-- Node Management
-- =========================================================================
s = m:section(TypedSection, "node", translate("Node Management"), 
	translate("Supported protocols: vmess, vless, trojan, ss, hysteria2.<br/>") ..
	translate("Batch import: paste multiple links in the link field (comma or newline separated)."))
s.template = "cbi/tblsection"
s.anonymous = true
s.addremove = true
s.sortable = true

o = s:option(Flag, "enable", translate("Enable"))
o.default = '1'
o.rmempty = false
o.width = "5%"

o = s:option(Value, "alias", translate("Alias"), translate("Give the node a name. For batch import:<br/>1. Leave empty: use original node name.<br/>2. Fill in: auto-name as 'Alias 1', 'Alias 2'..."))
o.width = "20%"

o = s:option(TextValue, "link", translate("Link"), translate("Paste the full share link. Batch paste supported."))
o.rows = 2
o.wrap = "off"
o.width = "75%"
-- Validate that it looks like a link
function o.validate(self, value)
	if value then
		value = value:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
		if (value:match("^vmess://") or value:match("^vless://") or value:match("^trojan://") or value:match("^ss://") or value:match("^hysteria2://")) then
			return value
		end
	end
	return nil, translate("Invalid link format. Must start with vmess://, vless://, trojan://, ss:// or hysteria2://")
end

return m
