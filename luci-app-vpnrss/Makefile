include $(TOPDIR)/rules.mk

LUCI_TITLE:=VPN RSS Subscription Generator
LUCI_DEPENDS:=+luci-base +luci-compat +luci-lib-jsonc +luci-lib-nixio
LUCI_PKGARCH:=all

PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-vpnrss/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/vpnrss
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/vpnrss
	$(INSTALL_DIR) $(1)/usr/lib/lua/vpnrss
	$(INSTALL_DIR) $(1)/etc/config
	
	$(INSTALL_DATA) ./luasrc/controller/vpnrss.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DATA) ./luasrc/model/cbi/vpnrss/*.lua $(1)/usr/lib/lua/luci/model/cbi/vpnrss/
	$(INSTALL_DATA) ./luasrc/view/vpnrss/*.htm $(1)/usr/lib/lua/luci/view/vpnrss/
	$(CP) ./root/etc $(1)/
	$(CP) ./root/usr/lib/lua/vpnrss $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,luci-app-vpnrss))
