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

-- === 6. 应用更改逻辑 (通过 Init 脚本) ===
function m.on_after_commit(self)
    -- Debug: 记录保存操作
    sys.call("logger -t simple2fa '[settings.lua] on_after_commit 被调用'")
    
    -- 重要修复: 创建一个新的 UCI cursor 来读取刚提交的配置
    -- 旧的 cursor (文件顶部创建的) 可能有缓存的旧值
    local fresh_uci = require("luci.model.uci").cursor()
    local enabled_val = fresh_uci:get("simple2fa", "global", "enabled")
    local enabled = (enabled_val == "1")
    
    sys.call(string.format("logger -t simple2fa '[settings.lua] 从新cursor读取: enabled_val=%s, enabled=%s'", 
        tostring(enabled_val), tostring(enabled)))
    
    if enabled then
        sys.call("logger -t simple2fa '[settings.lua] 执行: /etc/init.d/simple2fa enable'")
        sys.call("/etc/init.d/simple2fa enable")
        sys.call("logger -t simple2fa '[settings.lua] 执行: /etc/init.d/simple2fa start'")
        sys.call("/etc/init.d/simple2fa start")
    else
        sys.call("logger -t simple2fa '[settings.lua] 执行: /etc/init.d/simple2fa stop'")
        sys.call("/etc/init.d/simple2fa stop")
        sys.call("logger -t simple2fa '[settings.lua] 执行: /etc/init.d/simple2fa disable'")
        sys.call("/etc/init.d/simple2fa disable")
    end
    
    sys.call("logger -t simple2fa '[settings.lua] on_after_commit 完成'")
end

return m