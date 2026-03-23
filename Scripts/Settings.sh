#!/bin/bash

# 创建 uci-defaults 目录（确保路径存在）
mkdir -p ./package/base-files/files/etc/uci-defaults/

# 极致压榨 256M 内存：强制 ZRAM 使用 ZSTD 算法并调整大小
cat > ./package/base-files/files/etc/uci-defaults/99-zram-optimize <<EOF
#!/bin/sh
# 1. 强制修改启动脚本中的算法
sed -i 's/lzo-rle/zstd/g' /etc/init.d/zram

# 2. 如果存在 zramserver 配置文件，则通过 uci 设置参数（比 sed 更安全）
if [ -f "/etc/config/zramserver" ]; then
    uci set zramserver.@zramserver[0].comp_algorithm='zstd'
    uci set zramserver.@zramserver[0].size='128'
    uci commit zramserver
fi
exit 0
EOF

# 剩下的代码（从移除 attendedsysupgrade 开始）...
#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

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

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

# 高通平台专项调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
    # 取消nss相关feed
    echo "CONFIG_FEED_nss_packages=n" >> .config
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> .config
    
    # 设置NSS版本 (12.5)
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> .config
    if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
        echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> .config
    else
        echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> .config
    fi

    # --- 无WIFI配置 & 内存极致压榨开始 ---
    # 逻辑：如果配置名包含 "WIFI" 和 "NO"
    if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
        # 1. 切换 DTS 引用到 nowifi 版本
        find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
        
        # 2. 极致压榨 256M 内存：重写 ipq6018-nowifi.dtsi
        # 路径通常位于 target/linux/qualcommax/files/... (这是覆盖源码的最佳位置)
        NOWIFI_FILE="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-nowifi.dtsi"
        
        # 如果目录不存在则创建，确保重写成功
        mkdir -p $(dirname "$NOWIFI_FILE")
        
        # 使用 12MB (0x00800000) 方案，并彻底清空调试预留区 (3MB)
        cat > "$NOWIFI_FILE" <<EOF
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT
#include "ipq6018.dtsi"
&q6_region {
reg = <0x0 0x4ab00000 0x0 0x00E00000>;
};
EOF
        echo "256M Memory: Q6 region set to 8MB and debug regions removed!"

        # 3. 开启 ZRAM (256MB 设备的救命药)
        echo "CONFIG_PACKAGE_kmod-zram=y" >> .config
        echo "CONFIG_PACKAGE_zram-swap=y" >> .config
        
        echo "qualcommax set up nowifi successfully!"
    fi
    # --- 无WIFI配置 & 内存极致压榨结束 ---
fi
