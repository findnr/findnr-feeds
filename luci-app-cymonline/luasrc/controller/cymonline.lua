module("luci.controller.cymonline", package.seeall)

local http = require "luci.http"
local json = require "luci.jsonc"

function index()
	if not nixio.fs.access("/etc/config/cymonline") then
		return
	end

	-- Main menu entry
	entry({"admin", "status", "cymonline"}, template("cymonline/status"), _("Online Users"), 60)

	-- API endpoints
	entry({"admin", "status", "cymonline", "api", "devices"}, call("api_devices")).leaf = true
	entry({"admin", "status", "cymonline", "api", "remark"}, call("api_remark")).leaf = true
	entry({"admin", "status", "cymonline", "api", "limit"}, call("api_limit")).leaf = true
	entry({"admin", "status", "cymonline", "api", "delete"}, call("api_delete")).leaf = true
	entry({"admin", "status", "cymonline", "api", "settings"}, call("api_settings")).leaf = true
end

-- API: Get device list
function api_devices()
	local core = require "cymonline.core"
	local devices = core.get_devices()
	local settings = core.get_settings()

	http.prepare_content("application/json")
	http.write(json.stringify({
		devices = devices,
		settings = settings
	}))
end

-- API: Save remark
function api_remark()
	local core = require "cymonline.core"
	local mac = http.formvalue("mac")
	local remark = http.formvalue("remark") or ""

	if not mac then
		http.prepare_content("application/json")
		http.write(json.stringify({ success = false, error = "Missing MAC address" }))
		return
	end

	local ok = core.save_remark(mac, remark)

	http.prepare_content("application/json")
	http.write(json.stringify({ success = ok }))
end

-- API: Set speed limit
function api_limit()
	local core = require "cymonline.core"
	local mac = http.formvalue("mac")
	local up = http.formvalue("up") or "0"
	local down = http.formvalue("down") or "0"

	if not mac then
		http.prepare_content("application/json")
		http.write(json.stringify({ success = false, error = "Missing MAC address" }))
		return
	end

	local ok = core.set_limit(mac, up, down)

	http.prepare_content("application/json")
	http.write(json.stringify({ success = ok }))
end

-- API: Delete device record
function api_delete()
	local core = require "cymonline.core"
	local mac = http.formvalue("mac")

	if not mac then
		http.prepare_content("application/json")
		http.write(json.stringify({ success = false, error = "Missing MAC address" }))
		return
	end

	local ok = core.delete_device(mac)

	http.prepare_content("application/json")
	http.write(json.stringify({ success = ok }))
end

-- API: Get/Set settings
function api_settings()
	local core = require "cymonline.core"

	if http.getenv("REQUEST_METHOD") == "POST" then
		local interval = http.formvalue("interval")
		if interval then
			core.save_settings(interval)
		end
		http.prepare_content("application/json")
		http.write(json.stringify({ success = true }))
	else
		local settings = core.get_settings()
		http.prepare_content("application/json")
		http.write(json.stringify(settings))
	end
end
