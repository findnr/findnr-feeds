# findnr-feeds

## 简介

这是一个 OpenWrt （lede）的 LuCI 插件 `luci-app-simple2fa`，旨在为路由器登录添加 **TOTP 二次验证 (2FA)** 功能，这样在做内网穿透增加了一层安全防护。

<img width="1553" height="641" alt="image" src="https://github.com/user-attachments/assets/b0a029f8-9863-490b-95a1-59b25892e721" />
<img width="1036" height="663" alt="image" src="https://github.com/user-attachments/assets/60b42060-d15c-4a10-858e-328db5977a20" />

### ✨ 主要特性

#### luci-app-simple2fa (二次验证)
*   **安全拦截**：基于 CGI 层的拦截机制，有效防止未授权登录。
*   **无感植入**：动态替换系统文件，**安装/卸载不残留**，不破坏原有系统文件。
*   **中文界面**：全中文 UI，操作友好。
*   **便捷管理**：
    *   支持 **一键刷新密钥**。
    *   支持 **一键复制密钥**。
    *   支持 **二维码扫描** (Google Authenticator, Authy 等)。

#### luci-app-cymfrpc (客户端)
*   **最新核心**：自动编译最新版 `frpc` (v0.65.0+)。
*   **多实例管理**：支持同时运行多个 frpc 进程，互不干扰。
*   **纯文本配置**：所见即所得的配置方式，直接粘贴 `ini/toml/yaml`，支持所有 frp 高级特性。   
#### luci-app-cymfrps (服务端)
*   **最新核心**：自动编译最新版 `frps` (v0.65.0+)。
*   **多实例管理**：支持同时运行多个 frps 服务端进程。
*   **纯文本配置**：支持 `ini/toml/yaml` 格式。

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
