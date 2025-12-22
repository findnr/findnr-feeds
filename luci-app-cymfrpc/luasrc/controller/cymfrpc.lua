module("luci.controller.cymfrpc", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/cymfrpc") then
		return
	end

	entry({"admin", "services", "cymfrpc"}, cbi("cymfrpc/overview"), _("CymFrpc Client"), 60).dependent = true
	entry({"admin", "services", "cymfrpc", "instance"}, cbi("cymfrpc/instance"), nil).leaf = true
end
