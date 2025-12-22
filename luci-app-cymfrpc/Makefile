include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for CymFrpc
LUCI_DEPENDS:=+cymfrpc +luci-base +luci-compat
LUCI_PKGARCH:=all

PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-cymfrpc/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/cymfrpc
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	
	$(INSTALL_DATA) ./luasrc/controller/cymfrpc.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DATA) ./luasrc/model/cbi/cymfrpc/*.lua $(1)/usr/lib/lua/luci/model/cbi/cymfrpc/
	$(CP) ./root/etc/* $(1)/etc/
	sed -i 's/\r//' $(1)/etc/init.d/cymfrpc
	chmod +x $(1)/etc/init.d/cymfrpc
endef

$(eval $(call BuildPackage,luci-app-cymfrpc))
