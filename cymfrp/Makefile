include $(TOPDIR)/rules.mk

PKG_NAME:=cymfrp
PKG_VERSION:=0.65.0
PKG_RELEASE:=1

PKG_SOURCE:=frp-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/fatedier/frp/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=skip

PKG_BUILD_DIR:=$(BUILD_DIR)/frp-$(PKG_VERSION)

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=findnr

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

GO_PKG:=github.com/fatedier/frp
GO_PKG_BUILD_PKG:=github.com/fatedier/frp/cmd/frpc github.com/fatedier/frp/cmd/frps

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/../feeds/packages/lang/golang/golang-package.mk

define Package/cymfrpc
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Frp Client (Latest)
  URL:=https://github.com/fatedier/frp
  DEPENDS:=$(GO_ARCH_DEPENDS)
endef

define Package/cymfrpc/description
  Fast reverse proxy to help you expose a local server behind a NAT or firewall to the internet.
  This package contains the client binary (frpc).
endef

define Package/cymfrpc/install
	$(INSTALL_DIR) $(1)/usr/bin
	find $(PKG_BUILD_DIR) -name frpc -type f -exec $(INSTALL_BIN) {} $(1)/usr/bin/cymfrpc \;
endef

define Package/cymfrps
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Frp Server (Latest)
  URL:=https://github.com/fatedier/frp
  DEPENDS:=$(GO_ARCH_DEPENDS)
endef

define Package/cymfrps/description
  Fast reverse proxy to help you expose a local server behind a NAT or firewall to the internet.
  This package contains the server binary (frps).
endef

define Package/cymfrps/install
	$(INSTALL_DIR) $(1)/usr/bin
	find $(PKG_BUILD_DIR) -name frps -type f -exec $(INSTALL_BIN) {} $(1)/usr/bin/cymfrps \;
endef

$(eval $(call BuildPackage,cymfrpc))
$(eval $(call BuildPackage,cymfrps))


