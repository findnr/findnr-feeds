module("luci.controller.simple2fa", package.seeall)

function index()
    -- 注册菜单：系统 -> 2FA 设置
    if not nixio.fs.access("/etc/config/simple2fa") then
        return
    end
    
    entry({"admin", "system", "simple2fa"}, cbi("simple2fa/settings"), _("Two-Factor Auth"), 60)
end