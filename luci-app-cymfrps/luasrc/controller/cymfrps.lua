module("luci.controller.cymfrps", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/cymfrps") then
		return
	end

	entry({"admin", "services", "cymfrps"}, cbi("cymfrps/overview"), _("CymFrps Server"), 60).dependent = true
	entry({"admin", "services", "cymfrps", "instance"}, cbi("cymfrps/instance"), nil).leaf = true
end
