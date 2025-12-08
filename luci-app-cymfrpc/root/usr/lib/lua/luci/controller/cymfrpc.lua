module("luci.controller.cymfrpc", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/cymfrpc") then
		return
	end

	entry({"admin", "services", "cymfrpc"}, cbi("cymfrpc/overview"), _("CymFrpc 客户端"), 60).dependent = true
	entry({"admin", "services", "cymfrpc", "instance"}, cbi("cymfrpc/instance"), nil).leaf = true
end
