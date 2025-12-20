include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Online Users Manager
LUCI_DEPENDS:=+luci-base +luci-compat +tc +kmod-sched-core +iptables-mod-filter +iptables-mod-ipopt
LUCI_PKGARCH:=all

PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-cymonline/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/cymonline
	$(INSTALL_DIR) $(1)/usr/lib/lua/cymonline
	$(INSTALL_DIR) $(1)/usr/lib/cymonline

	$(INSTALL_DATA) ./luasrc/controller/cymonline.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DATA) ./luasrc/view/cymonline/*.htm $(1)/usr/lib/lua/luci/view/cymonline/
	$(CP) ./root/etc/* $(1)/etc/
	$(CP) ./root/usr/lib/lua/cymonline/* $(1)/usr/lib/lua/cymonline/
	$(CP) ./root/usr/lib/cymonline/* $(1)/usr/lib/cymonline/
	
	# Fix CRLF line endings
	find $(1) -type f \( -name "*.lua" -o -name "*.htm" -o -name "*.sh" \) -exec sed -i 's/\r//' {} \;
	sed -i 's/\r//' $(1)/etc/init.d/cymonline
	sed -i 's/\r//' $(1)/etc/config/cymonline
	chmod +x $(1)/etc/init.d/cymonline
	chmod +x $(1)/usr/lib/cymonline/*.sh
endef

define Package/luci-app-cymonline/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/cymonline enable
	/etc/init.d/cymonline start
}
exit 0
endef

define Package/luci-app-cymonline/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/cymonline stop
	/etc/init.d/cymonline disable
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-cymonline))
