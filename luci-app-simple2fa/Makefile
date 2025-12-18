include $(TOPDIR)/rules.mk

LUCI_TITLE:=Simple 2FA (TOTP) for Login
LUCI_DEPENDS:=+oath-toolkit +qrencode +luci-base +luci-compat
LUCI_PKGARCH:=all

PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-simple2fa/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/simple2fa
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/simple2fa
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/usr/share/luci-app-simple2fa
	
	$(INSTALL_DATA) ./luasrc/controller/simple2fa.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DATA) ./luasrc/model/cbi/simple2fa/*.lua $(1)/usr/lib/lua/luci/model/cbi/simple2fa/
	$(INSTALL_DATA) ./luasrc/view/simple2fa/*.htm $(1)/usr/lib/lua/luci/view/simple2fa/
	$(CP) ./root/etc/config $(1)/etc/
	$(INSTALL_BIN) ./root/etc/uci-defaults/99_simple2fa_setup $(1)/etc/uci-defaults/
	$(INSTALL_BIN) ./root/usr/share/luci-app-simple2fa/luci $(1)/usr/share/luci-app-simple2fa/luci
endef

define Package/luci-app-simple2fa/prerm
#!/bin/sh
if [ -f "/www/cgi-bin/luci.bak" ]; then
	mv -f /www/cgi-bin/luci.bak /www/cgi-bin/luci
fi
exit 0
endef

$(eval $(call BuildPackage,luci-app-simple2fa))
