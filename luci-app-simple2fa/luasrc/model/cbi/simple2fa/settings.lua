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
            <code id="secret_code" style="font-size: 1.2em; margin-right: 10px; background: #f0f0f0; padding: 5px; border-radius: 3px;">%s</code>
            <input type="button" class="cbi-button cbi-button-apply" value="Copy" onclick="
                var code = document.getElementById('secret_code');
                var range = document.createRange();
                range.selectNode(code);
                window.getSelection().removeAllRanges();
                window.getSelection().addRange(range);
                document.execCommand('copy');
                window.getSelection().removeAllRanges();
                alert('Copied!');
            " />
        </div>
    ]], val)
end

-- === 4. 刷新密钥按钮 ===
local btn = s:option(Button, "_refresh", translate("Refresh Secret"))
btn.inputstyle = "remove"
btn.description = translate("Warning: After refreshing, you must reconfigure all authenticator apps.")
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

-- === 6. 应用更改逻辑 (文件替换) ===
function m.on_after_commit(self)
    local enabled = uci:get("simple2fa", "global", "enabled") == "1"
    
    -- 定义文件路径
    local files = {
        {
            origin = "/www/cgi-bin/luci",
            backup = "/www/cgi-bin/luci.bak",
            target = "/usr/share/luci-app-simple2fa/luci"
        },
        {
            origin = "/www/luci-static/resources/view/bootstrap/sysauth.js",
            backup = "/www/luci-static/resources/view/bootstrap/sysauth.js.bak",
            target = "/usr/share/luci-app-simple2fa/sysauth.js"
        }
    }

    if enabled then
        -- 启用：备份原文件 -> 覆盖
        for _, f in ipairs(files) do
            -- 1. 如果没有备份，先备份
            if not nixio.fs.access(f.backup) and nixio.fs.access(f.origin) then
                nixio.fs.copy(f.origin, f.backup)
            end
            
            -- 2. 用我们的文件覆盖原文件
            if nixio.fs.access(f.target) then
                -- 先删除原文件 (cp 可能会失败如果目标是只读等情况，虽然这里应该没事)
                nixio.fs.remove(f.origin)
                nixio.fs.copy(f.target, f.origin)
                nixio.fs.chmod(f.origin, 755) -- 确保可执行
            end
        end
    else
        -- 禁用：还原备份
        for _, f in ipairs(files) do
            if nixio.fs.access(f.backup) then
                nixio.fs.remove(f.origin)
                nixio.fs.move(f.backup, f.origin)
                nixio.fs.chmod(f.origin, 755)
            end
        end
    end
end

return m