include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cymfrps
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=findnr

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-cymfrps
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI Support for CymFrps
  DEPENDS:=+cymfrps
  PKGARCH:=all
endef

define Package/luci-app-cymfrps/description
  LuCI support for CymFrps (Multi-instance, Raw Config).
endef

define Build/Compile
endef

define Package/luci-app-cymfrps/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/cymfrps

	$(CP) ./root/* $(1)/
	# Fix CRLF line endings
	sed -i 's/\r//' $(1)/etc/init.d/cymfrps
	chmod +x $(1)/etc/init.d/cymfrps
endef

$(eval $(call BuildPackage,luci-app-cymfrps))
