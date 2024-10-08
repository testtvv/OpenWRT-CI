#!/bin/bash

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
#修改默认WIFI名
sed -i "s/\.ssid=.*/\.ssid=$WRT_WIFI/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-fs-ext4=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-core=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-dwc3=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-dwc3-qcom=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb-xhci-hcd=n" >> ./.config
echo "CONFIG_PACKAGE_kmod-usb3=n" >> ./.config
#配置文件修改
#echo "CONFIG_PACKAGE_iptables-mod-filter=y" >> ./.config
#echo "CONFIG_PACKAGE_kmod-ipt-filter=y" >> ./.config
#echo "CONFIG_PACKAGE_snmpd=y" >> ./.config
#echo "CONFIG_PACKAGE_iptables=y" >> ./.config
#echo "CONFIG_PACKAGE_kmod-ipt-nat=y" >> ./.config
#echo "CONFIG_PACKAGE_kmod-nf-nat=y" >> ./.config
#echo "CONFIG_PACKAGE_luci-app-accesscontrol-plus=y" >> ./.config
#echo "CONFIG_PACKAGE_luci-app-parentcontrol=y" >> ./.config
# 禁用 firewall 并启用 firewall4
#echo "# CONFIG_PACKAGE_firewall is not set" >> ./.config
#echo "CONFIG_PACKAGE_firewall4=y" >> ./.config


#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
if [[ $WRT_TARGET == *"IPQ"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#更换nss版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=y" >> ./.config
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=n" >> ./.config	
fi
