local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"

-- 定义生成密钥的函数
local function generate_secret()
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    local s = ""
    local f = io.open("/dev/urandom", "rb")
    if f then
        local bytes = f:read(10)
        f:close()
        local val = 0
        local bits = 0
        for i = 1, #bytes do
            val = val * 256 + string.byte(bytes, i)
            bits = bits + 8
            while bits >= 5 do
                local idx = math.floor(val / (2 ^ (bits - 5))) % 32
                s = s .. string.sub(charset, idx + 1, idx + 1)
                bits = bits - 5
            end
        end
    else
        math.randomseed(os.time())
        for i = 1, 16 do
            local r = math.random(1, 32)
            s = s .. string.sub(charset, r, r)
        end
    end
    return s
end

local m = Map("simple2fa", translate("Two-Factor Authentication"), translate("Enable 2FA to protect your router login."))

-- === 1. 自动初始化密钥 ===
local secret = uci:get("simple2fa", "global", "secret")
if not secret or #secret < 16 then
    secret = generate_secret()
    uci:set("simple2fa", "global", "secret", secret)
    uci:commit("simple2fa")
end

local s = m:section(NamedSection, "global", "settings", translate("Settings"))

-- === 2. 功能开关 ===
s:option(Flag, "enabled", translate("Enable Two-Factor Auth"))

-- === 3. 显示密钥 (带复制功能) ===
local o = s:option(DummyValue, "_secret_display", translate("Secret Key"))
o.description = translate("If you cannot scan the QR code, enter this key manually.")
o.rawhtml = true
o.cfgvalue = function(self, section)
    local val = uci:get("simple2fa", section, "secret") or ""
    return string.format([[
        <div style="display: flex; align-items: center;">
            <code id="secret_code" style="font-size: 1.2em; margin-right: 10px; padding: 5px; border: 1px solid rgba(0,0,0,0.1); border-radius: 3px;">%s</code>
            <input type="button" class="cbi-button cbi-button-apply" value="]] .. translate("Copy") .. [[" onclick="
                var code = document.getElementById('secret_code');
                var range = document.createRange();
                range.selectNode(code);
                window.getSelection().removeAllRanges();
                window.getSelection().addRange(range);
                document.execCommand('copy');
                window.getSelection().removeAllRanges();
                alert(']] .. translate("Copied!") .. [[');
            " />
        </div>
    ]], val)
end

-- === 4. 刷新密钥按钮 ===
local btn = s:option(Button, "_refresh", translate("Refresh Secret"))
btn.inputstyle = "remove"
btn.description = translate("Warning: After refreshing, you must reconfigure all authenticator apps.") .. [[
<script type="text/javascript">
    // 使用 setTimeout 确保 DOM 渲染完成
    setTimeout(function() {
        var btn = document.getElementsByName('cbid.simple2fa.global._refresh')[0];
        if (btn) {
            btn.onclick = function() {
                return confirm(']] .. translate("Are you sure you want to refresh the secret key? This will invalidate your current authenticator setup.") .. [[');
            };
        }
    }, 500);
</script>
]]
btn.write = function(self, section)
    local new_secret = generate_secret()
    uci:set("simple2fa", section, "secret", new_secret)
    uci:commit("simple2fa")
    -- 刷新页面以显示新密钥和二维码
    http.redirect(dispatcher.build_url("admin", "system", "simple2fa"))
end

-- === 5. 生成二维码 ===
local hostname = sys.hostname() or "OpenWrt"
local otp_url = string.format("otpauth://totp/%s:root?secret=%s&issuer=%s", hostname, secret, hostname)

local qr = s:option(DummyValue, "_qrcode", translate("Scan QR Code"))
qr.description = translate("Use Google Authenticator, Authy or Microsoft Auth to scan this QR code.")
qr.template = "simple2fa/qrcode_view" 
qr.otp_url = otp_url 

-- === 6. 应用更改逻辑 (直接在 Lua 中操作，避免 shell UCI 竞态) ===
function m.on_after_commit(self)
    local fs = require("nixio.fs")
    
    sys.call("logger -t simple2fa '[settings.lua] on_after_commit 被调用'")
    
    -- 目标文件
    local CGI_TARGET = "/www/cgi-bin/luci"
    local SYSAUTH_TARGET = "/usr/lib/lua/luci/view/sysauth.htm"
    local CGI_SOURCE = "/usr/share/luci-app-simple2fa/luci"
    local SYSAUTH_SOURCE = "/usr/share/luci-app-simple2fa/sysauth.htm"
    
    -- 从新 cursor 读取配置
    local fresh_uci = require("luci.model.uci").cursor()
    local enabled_val = fresh_uci:get("simple2fa", "global", "enabled")
    local enabled = (enabled_val == "1")
    
    sys.call(string.format("logger -t simple2fa '[settings.lua] enabled_val=%s, enabled=%s'", 
        tostring(enabled_val), tostring(enabled)))
    
    if enabled then
        sys.call("logger -t simple2fa '[settings.lua] 启用 2FA - 开始替换文件'")
        
        -- 备份 CGI
        if fs.access(CGI_TARGET) and not fs.access(CGI_TARGET .. ".bak") then
            local content = fs.readfile(CGI_TARGET)
            if content and not content:match("Simple2FA") then
                fs.writefile(CGI_TARGET .. ".bak", content)
                sys.call("logger -t simple2fa '[settings.lua] CGI 备份成功'")
            end
        end
        
        -- 备份 sysauth.htm
        if fs.access(SYSAUTH_TARGET) and not fs.access(SYSAUTH_TARGET .. ".bak") then
            local content = fs.readfile(SYSAUTH_TARGET)
            if content then
                fs.writefile(SYSAUTH_TARGET .. ".bak", content)
                sys.call("logger -t simple2fa '[settings.lua] 模板备份成功'")
            end
        end
        
        -- 安装我们的 CGI
        if fs.access(CGI_SOURCE) then
            local content = fs.readfile(CGI_SOURCE)
            if content then
                fs.writefile(CGI_TARGET, content)
                fs.chmod(CGI_TARGET, 755)
                sys.call("logger -t simple2fa '[settings.lua] CGI 安装成功'")
            end
        else
            sys.call("logger -t simple2fa '[settings.lua] 错误: CGI 源文件不存在'")
        end
        
        -- 安装我们的 sysauth.htm
        if fs.access(SYSAUTH_SOURCE) then
            local content = fs.readfile(SYSAUTH_SOURCE)
            if content then
                fs.writefile(SYSAUTH_TARGET, content)
                sys.call("logger -t simple2fa '[settings.lua] 模板安装成功'")
            end
        else
            sys.call("logger -t simple2fa '[settings.lua] 错误: 模板源文件不存在'")
        end
        
        -- 启用 init 脚本 (仅用于开机启动)
        sys.call("/etc/init.d/simple2fa enable 2>/dev/null")
        
        sys.call("logger -t simple2fa '[settings.lua] 2FA 已激活'")
    else
        sys.call("logger -t simple2fa '[settings.lua] 禁用 2FA - 开始恢复文件'")
        
        -- 恢复 CGI
        if fs.access(CGI_TARGET .. ".bak") then
            local content = fs.readfile(CGI_TARGET .. ".bak")
            if content then
                fs.writefile(CGI_TARGET, content)
                fs.chmod(CGI_TARGET, 755)
                fs.remove(CGI_TARGET .. ".bak")
                sys.call("logger -t simple2fa '[settings.lua] CGI 恢复成功'")
            end
        end
        
        -- 恢复 sysauth.htm
        if fs.access(SYSAUTH_TARGET .. ".bak") then
            local content = fs.readfile(SYSAUTH_TARGET .. ".bak")
            if content then
                fs.writefile(SYSAUTH_TARGET, content)
                fs.remove(SYSAUTH_TARGET .. ".bak")
                sys.call("logger -t simple2fa '[settings.lua] 模板恢复成功'")
            end
        end
        
        -- 禁用 init 脚本
        sys.call("/etc/init.d/simple2fa disable 2>/dev/null")
        
        sys.call("logger -t simple2fa '[settings.lua] 2FA 已禁用'")
    end
    
    sys.call("logger -t simple2fa '[settings.lua] on_after_commit 完成'")
end

return m