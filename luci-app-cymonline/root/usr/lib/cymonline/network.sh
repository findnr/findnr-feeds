#!/bin/sh
# CymOnline Network Control Script
# Provides traffic monitoring and speed limiting via nftables + tc (fw4 compatible)

. /lib/functions.sh

# Configuration
FW_TABLE="inet cymonline"

# Get interface from UCI or use defaults
get_interfaces() {
	config_load cymonline
	config_get WAN_IFACE main wan_iface "eth0"
	config_get LAN_IFACE main lan_iface "br-lan"
}

# ============================================================
# Traffic Monitoring (nftables dynamic sets)
# ============================================================

init_traffic() {
	get_interfaces

	# Ensure nft is available
	which nft >/dev/null 2>&1 || {
		echo "ERROR: nft command not found"
		return 1
	}

	# Clean up any old table and re-create it
	nft delete table $FW_TABLE 2>/dev/null
	nft add table $FW_TABLE

	# Create dynamic sets for RX/TX bytes and block set
	# Timeout ensures offline devices eventually get cleared
	nft add set $FW_TABLE rx_bytes "{ type ipv4_addr; flags dynamic; timeout 30d; counter; }"
	nft add set $FW_TABLE tx_bytes "{ type ipv4_addr; flags dynamic; timeout 30d; counter; }"
	nft add set $FW_TABLE block_set "{ type ipv4_addr; }"

	# Hook into FORWARD chain to catch routed traffic
	nft add chain $FW_TABLE forward "{ type filter hook forward priority filter; policy accept; }"

	# Block traffic for IPs in block_set
	nft add rule $FW_TABLE forward ip saddr @block_set drop
	nft add rule $FW_TABLE forward ip daddr @block_set drop

	# Update sets directly on matched packets
	# Traffic TO an IP: daddr
	nft add rule $FW_TABLE forward update @rx_bytes "{ ip daddr counter }"
	# Traffic FROM an IP: saddr
	nft add rule $FW_TABLE forward update @tx_bytes "{ ip saddr counter }"

	# Hook POSTROUTING for download limiting (traffic going to devices out on LAN_IFACE)
	nft add chain $FW_TABLE postrouting "{ type filter hook postrouting priority mangle; policy accept; }"
	nft add map $FW_TABLE limit_map "{ type ipv4_addr : mark; }"

	# Apply mark based on the limit_map
	nft add rule $FW_TABLE postrouting meta mark set ip daddr map @limit_map

	echo "Traffic monitoring initialized (nftables)"
}

cleanup_traffic() {
	nft delete table $FW_TABLE 2>/dev/null
	echo "Traffic monitoring cleaned up"
}

# In nftables with dynamic sets, we don't need to manually add counters for new IPs! 
# They are added atomically upon seeing traffic.
add_traffic_counter() {
	# Keep function for backward compatibility with lua scripts that might still call it,
	# but no operation needed.
	:
}

# Kept for backward compatibility, although get_all_stats is preferred
get_traffic_stats() {
	local ip="$1"
	local rx_bytes=$(nft list set $FW_TABLE rx_bytes 2>/dev/null | grep -oE "$ip counter packets [0-9]+ bytes [0-9]+" | awk '{print $6}')
	local tx_bytes=$(nft list set $FW_TABLE tx_bytes 2>/dev/null | grep -oE "$ip counter packets [0-9]+ bytes [0-9]+" | awk '{print $6}')
	
	echo "${rx_bytes:-0} ${tx_bytes:-0} 0 0" 
}

# Get all traffic stats at once (returns lines of: IP RX_BYTES TX_BYTES)
get_all_stats() {
	# Use regex grep to pull the exact element strings regardless of how nft formats the output array
	local rx_out=$(nft list set $FW_TABLE rx_bytes 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ counter packets [0-9]+ bytes [0-9]+' || echo "")
	local tx_out=$(nft list set $FW_TABLE tx_bytes 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ counter packets [0-9]+ bytes [0-9]+' || echo "")

	awk -v rx="$rx_out" -v tx="$tx_out" '
	BEGIN {
		split(rx, ra, "\n")
		for (i in ra) {
			split(ra[i], r_elem, " ")
			if (r_elem[1]) r[r_elem[1]] = r_elem[6]
		}
		
		split(tx, ta, "\n")
		for (i in ta) {
			split(ta[i], t_elem, " ")
			if (t_elem[1]) t[t_elem[1]] = t_elem[6]
		}
		
		for (ip in r) {
			print ip, r[ip], (t[ip] ? t[ip] : 0)
			seen[ip] = 1
		}
		for (ip in t) {
			if (!seen[ip]) {
				print ip, 0, t[ip]
			}
		}
	}'
}

# ============================================================
# Speed Limiting (tc HTB on LAN interface)
# ============================================================

init_tc() {
	get_interfaces

	which tc >/dev/null 2>&1 || {
		echo "ERROR: tc command not found"
		return 1
	}

	tc qdisc del dev "$LAN_IFACE" root 2>/dev/null
	tc qdisc add dev "$LAN_IFACE" root handle 1: htb default 9999
	tc class add dev "$LAN_IFACE" parent 1: classid 1:1 htb rate 1000mbit ceil 1000mbit
	tc class add dev "$LAN_IFACE" parent 1:1 classid 1:9999 htb rate 1000mbit ceil 1000mbit

	echo "TC qdisc initialized on $LAN_IFACE"
}

cleanup_tc() {
	get_interfaces
	tc qdisc del dev "$LAN_IFACE" root 2>/dev/null
	echo "TC qdisc cleaned up"
}

mac_to_mark() {
	local mac="$1"
	# Better collision resistance: use MD5 hash truncated to avoid just last 2 bytes collision
	local hashStr=$(echo "$mac" | md5sum | cut -c 1-5)
	# Convert hex snippet to a decimal mark, keep under 65000 range map for standard classid usage
	local mark=$(printf "%d" "0x$hashStr" 2>/dev/null)
	mark=$(( mark % 60000 + 100 ))
	echo "$mark"
}

ensure_tc_ready() {
	get_interfaces
	tc qdisc show dev "$LAN_IFACE" 2>/dev/null | grep -q "htb 1:" || {
		echo "Initializing tc..."
		init_tc
	}
}

set_limit() {
	local mac="$1"
	local up_kbps="$2"
	local down_kbps="$3"

	get_interfaces
	
	[ -z "$mac" ] && { echo "ERROR: MAC required"; return 1; }

	mac=$(echo "$mac" | tr 'a-f' 'A-F')

	[ "$up_kbps" = "0" ] && [ "$down_kbps" = "0" ] && {
		remove_limit "$mac"
		return 0
	}

	ensure_tc_ready

	local mark=$(mac_to_mark "$mac")
	local classid=$((mark % 9000 + 10))

	echo "Setting limit for MAC=$mac mark=$mark classid=1:$classid down=${down_kbps}kbps"

	# Safe remove first
	remove_limit "$mac"

	local ip=$(cat /proc/net/arp | grep -i "$mac" | awk '{print $1}' | head -1)
	
	if [ -z "$ip" ]; then
		echo "WARNING: Cannot find IP for MAC $mac (device may be offline)"
	fi

	if [ "$down_kbps" != "0" ] && [ -n "$down_kbps" ]; then
		tc class add dev "$LAN_IFACE" parent 1:1 classid "1:$classid" htb rate "${down_kbps}kbit" ceil "${down_kbps}kbit" 2>/dev/null
		tc filter add dev "$LAN_IFACE" parent 1: protocol ip prio 1 handle "$mark" fw flowid "1:$classid" 2>/dev/null
		
		# nftables map injection
		if [ -n "$ip" ]; then
			nft add element $FW_TABLE limit_map "{ $ip : $mark }" 2>/dev/null
			echo "Added nftables limit element for IP $ip -> mark $mark"
		fi
	fi

	return 0
}

set_block() {
	local mac="$1"
	local blocked="$2"
	get_interfaces

	[ -z "$mac" ] && { echo "ERROR: MAC required"; return 1; }
	mac=$(echo "$mac" | tr 'a-f' 'A-F')

	local ip=$(cat /proc/net/arp | grep -i "$mac" | awk '{print $1}' | head -1)
	
	if [ -n "$ip" ]; then
		if [ "$blocked" = "1" ]; then
			nft add element $FW_TABLE block_set "{ $ip }" 2>/dev/null
			echo "Blocked IP $ip (MAC $mac)"
		else
			nft delete element $FW_TABLE block_set "{ $ip }" 2>/dev/null
			echo "Unblocked IP $ip (MAC $mac)"
		fi
	else
		echo "WARNING: Cannot find IP for MAC $mac (device may be offline)"
	fi
}

remove_block() {
	local mac="$1"
	get_interfaces

	mac=$(echo "$mac" | tr 'a-f' 'A-F')
	local ip=$(cat /proc/net/arp | grep -i "$mac" | awk '{print $1}' | head -1)

	if [ -n "$ip" ]; then
		nft delete element $FW_TABLE block_set "{ $ip }" 2>/dev/null
		echo "Removed block for IP $ip (MAC $mac)"
	fi
}

remove_limit() {
	local mac="$1"
	get_interfaces

	mac=$(echo "$mac" | tr 'a-f' 'A-F')
	local mark=$(mac_to_mark "$mac")
	local classid=$((mark % 9000 + 10))

	local ip=$(cat /proc/net/arp | grep -i "$mac" | awk '{print $1}' | head -1)

	if [ -n "$ip" ]; then
		# Exact element match deletion via nftables
		nft delete element $FW_TABLE limit_map "{ $ip }" 2>/dev/null
	fi

	tc filter del dev "$LAN_IFACE" parent 1: handle "$mark" fw 2>/dev/null
	tc class del dev "$LAN_IFACE" classid "1:$classid" 2>/dev/null
}

restore_limits() {
	echo "Restoring speed limits and blocks from config..."
	init_tc

	config_load cymonline

	restore_device_limit() {
		local cfg="$1"
		local mac limit_up limit_down blocked

		config_get mac "$cfg" mac
		config_get limit_up "$cfg" limit_up "0"
		config_get limit_down "$cfg" limit_down "0"
		config_get blocked "$cfg" blocked "0"

		if [ -n "$mac" ]; then
			if [ "$limit_up" != "0" ] || [ "$limit_down" != "0" ]; then
				echo "Restoring limit for $mac: up=$limit_up down=$limit_down"
				set_limit "$mac" "$limit_up" "$limit_down"
			fi
			if [ "$blocked" = "1" ]; then
				echo "Restoring block for $mac"
				set_block "$mac" "1"
			fi
		fi
	}

	config_foreach restore_device_limit device
	echo "Speed limits restored"
}

cleanup_limits() {
	cleanup_tc
	nft flush map $FW_TABLE limit_map 2>/dev/null
}

show_status() {
	echo "=== Interfaces ==="
	get_interfaces
	echo "WAN: $WAN_IFACE"
	echo "LAN: $LAN_IFACE"
	
	echo ""
	echo "=== TC Qdisc ==="
	tc qdisc show dev "$LAN_IFACE" 2>/dev/null
	
	echo ""
	echo "=== TC Classes ==="
	tc class show dev "$LAN_IFACE" 2>/dev/null
	
	echo ""
	echo "=== TC Filters ==="
	tc filter show dev "$LAN_IFACE" 2>/dev/null
	
	echo ""
	echo "=== nftables rules ==="
	nft list table $FW_TABLE 2>/dev/null
}

# ============================================================
# Main Entry
# ============================================================

case "$1" in
	init_traffic)
		init_traffic
		;;
	cleanup_traffic)
		cleanup_traffic
		;;
	add_counter)
		add_traffic_counter "$2"
		;;
	get_stats)
		get_traffic_stats "$2"
		;;
	get_all_stats)
		get_all_stats
		;;
	init_tc)
		init_tc
		;;
	set_limit)
		set_limit "$2" "$3" "$4"
		;;
	remove_limit)
		remove_limit "$2"
		;;
		;;
	set_block)
		set_block "$2" "$3"
		;;
	remove_block)
		remove_block "$2"
		;;
	restore_limits)
		restore_limits
		;;
	cleanup_limits)
		cleanup_limits
		;;
	status)
		show_status
		;;
	*)
		echo "Usage: $0 {init_traffic|cleanup_traffic|add_counter|get_stats|get_all_stats|init_tc|set_limit|remove_limit|set_block|remove_block|restore_limits|cleanup_limits|status}"
		exit 1
		;;
esac
