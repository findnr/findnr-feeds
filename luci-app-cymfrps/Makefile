include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Support for CymFrps
LUCI_DEPENDS:=+cymfrps +luci-base +luci-compat
LUCI_PKGARCH:=all

PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-cymfrps/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/cymfrps
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	
	$(INSTALL_DATA) ./luasrc/controller/cymfrps.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DATA) ./luasrc/model/cbi/cymfrps/*.lua $(1)/usr/lib/lua/luci/model/cbi/cymfrps/
	$(CP) ./root/etc/* $(1)/etc/
	sed -i 's/\r//' $(1)/etc/init.d/cymfrps
	chmod +x $(1)/etc/init.d/cymfrps
endef

$(eval $(call BuildPackage,luci-app-cymfrps))
