include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cymfrpc
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=findnr

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-cymfrpc
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI Support for CymFrpc
  DEPENDS:=+cymfrpc
  PKGARCH:=all
endef

define Package/luci-app-cymfrpc/description
  LuCI support for CymFrpc (Multi-instance, Raw Config).
endef

define Build/Compile
endef

define Package/luci-app-cymfrpc/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/cymfrpc

	$(CP) ./root/* $(1)/
	# Fix CRLF line endings
	sed -i 's/\r//' $(1)/etc/init.d/cymfrpc
	chmod +x $(1)/etc/init.d/cymfrpc
endef

$(eval $(call BuildPackage,luci-app-cymfrpc))
