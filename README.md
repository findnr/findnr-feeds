# findnr-feeds

## 简介

- luci-app-simple2fa，旨在为路由器登录添加 **TOTP 二次验证 (2FA)** 功能，这样在做内网穿透增加了一层安全防护。
- luci-app-cymfrpc (客户端)` , **多实例管理**：支持同时运行多个 frpc 进程，互不干扰。
- luci-app-cymfrps (服务端)，支持同时运行多个 frps 服务端进程。
- luci-app-vpnrss (订阅生成器)，支持多协议聚合与转换 (Clash/Sing-box/Hysteria2)。

### ✨ 主要特性

#### luci-app-simple2fa (二次验证)
*   **安全拦截**：基于 CGI 层的拦截机制，有效防止未授权登录。
*   **全主题兼容**：通过动态 JS 注入，**支持所有 LuCI 主题**（bootstrap、argon、material 等）。
*   **无感植入**：动态替换系统文件，**安装/卸载不残留**，不破坏原有系统文件。
*   **中文界面**：全中文 UI，操作友好。
*   **便捷管理**：
    *   支持 **一键刷新密钥**。
    *   支持 **一键复制密钥**。
    *   支持 **二维码扫描** (Google Authenticator, Authy 等)。
    *   
<img width="1036" height="663" alt="image" src="https://github.com/user-attachments/assets/60b42060-d15c-4a10-858e-328db5977a20" />

#### luci-app-cymfrpc (客户端)
*   **最新核心**：自动编译最新版 `frpc` (v0.65.0+)。
*   **多实例管理**：支持同时运行多个 frpc 进程，互不干扰。
*   **纯文本配置**：所见即所得的配置方式，直接粘贴 `ini/toml/yaml`，支持所有 frp 高级特性。
<img width="980" height="439" alt="image" src="https://github.com/user-attachments/assets/3c498e68-7142-4483-b110-d1667e8a00f0" />

#### luci-app-cymfrps (服务端)
*   **最新核心**：自动编译最新版 `frps` (v0.65.0+)。
*   **多实例管理**：支持同时运行多个 frps 服务端进程。
*   **纯文本配置**：支持 `ini/toml/yaml` 格式。
<img width="958" height="371" alt="image" src="https://github.com/user-attachments/assets/16c1448b-a6bf-4771-9c98-fcc0b438d604" />

#### luci-app-vpnrss (VPN 订阅生成器)
*   **订阅聚合**：将多个零散节点聚合为一个订阅链接。
*   **多协议支持**：支持 `vmess`, `vless`, `trojan`, `ss`, `hysteria2`。
*   **多客户端适配**：自动生成 **Clash**, **Sing-box**, **Surge**, **Passwall/SSR+ (Base64)** 格式配置。
*   **智能导入**：
    *   支持**批量导入**：在一个输入框内粘贴多条链接（逗号或换行分隔）。
    *   **智能命名**：自动为批量导入的节点添加序号（如 "香港 1", "香港 2"），避免重名。
*   **安全保护**：支持 Token 访问控制，防止订阅被扫描。

## 安装说明

- **依赖**：`oath-toolkit`、`qrencode` (安装插件时会自动安装)

### 方式一：通过 OpenWrt feeds 集成构建
1. 在 OpenWrt (lede) 源码目录中添加本地 feed（推荐）：
```bash
echo "src-git findnrfeeds https://github.com/findnr/findnr-feeds.git" >> feeds.conf
./scripts/feeds update findnrfeeds
./scripts/feeds install luci-app-simple2fa
./scripts/feeds install luci-app-simple2fa
./scripts/feeds install cymfrp
./scripts/feeds install luci-app-cymfrpc
./scripts/feeds install luci-app-cymfrps
./scripts/feeds install luci-app-vpnrss
```

2. 选择并编译：

```bash
make menuconfig
# LuCI -> Applications -> luci-app-simple2fa 选为 <*> 或 <M>
# LuCI -> Applications -> luci-app-cymfrpc 选为 <*> 或 <M>
# LuCI -> Applications -> luci-app-cymfrps 选为 <*> 或 <M>
make -j$(nproc)
```

### 方式二：单包本地编译并安装

1. 在 OpenWrt 源码目录中执行：

```bash
make package/feeds/findnrfeeds/luci-app-simple2fa/compile V=s
make package/feeds/findnrfeeds/luci-app-simple2fa/compile V=s
make package/feeds/findnrfeeds/cymfrp/compile V=s
make package/feeds/findnrfeeds/luci-app-cymfrpc/compile V=s
make package/feeds/findnrfeeds/luci-app-cymfrps/compile V=s
make package/feeds/findnrfeeds/luci-app-vpnrss/compile V=s
```

2. 将生成的 `.ipk` 拷贝到路由器并安装：

```bash
scp bin/packages/*/findnrfeeds/luci-app-simple2fa_*.ipk root@<router>:/tmp/
ssh root@<router> opkg update
ssh root@<router> opkg install /tmp/luci-app-simple2fa_*.ipk
```

## 启用与使用

1.  **进入设置**：Web 界面 → 系统 (System) → 双因素认证 (Two-Factor Auth)。
2.  **绑定设备**：
    *   使用手机 APP 扫描屏幕上的二维码。
    *   或者点击“复制”按钮获取密钥手动输入。
3.  **启用功能**：勾选“启用二次验证”，点击“保存并应用”。
4.  **验证登录**：注销后重新登录，输入账号密码后，会跳转到验证码输入框。

## 故障排查

- **二维码不显示**：
    *   请确认已安装 `qrencode`：`opkg install qrencode`。
    *   检查 `/tmp/simple2fa_qr.err` 日志。
- **验证一直失败**：
    *   **时间同步**：TOTP 极其依赖时间，请确保路由器时间与手机时间误差在 30 秒以内。
    *   尝试点击“刷新密钥”重新绑定。
- **卸载后登录页异常**：
    *   插件自带卸载恢复脚本。如果意外残留，请检查 `/www/cgi-bin/luci.bak` 是否存在，手动还原即可。

## 开发说明

### 目录结构

所有 LuCI 包均采用标准 `luci.mk` 结构：

```
luci-app-xxx/
├── Makefile          # 使用 luci.mk
├── luasrc/           # Lua 源码
│   ├── controller/   # 控制器
│   ├── model/cbi/    # CBI 模型
│   └── view/         # 视图模板 (如有)
├── root/             # 其他文件 (config, init.d 等)
└── po/               # 翻译文件
    ├── templates/xxx.pot   # 翻译模板
    └── zh_Hans/xxx.po      # 简体中文翻译
```

### i18n 国际化

- 源码使用英文 `translate("English Text")`
- 中文翻译通过 `po/zh_Hans/*.po` 提供
- 编译时自动生成 `luci-i18n-xxx-zh-cn` 翻译包

### Makefile 示例

```makefile
include $(TOPDIR)/rules.mk

LUCI_TITLE:=Your App Title
LUCI_DEPENDS:=+luci-base +luci-compat
LUCI_PKGARCH:=all

PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,luci-app-xxx))
```
