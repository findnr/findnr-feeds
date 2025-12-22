-- CymOnline Core Library
-- Provides device detection, traffic stats, and management functions

module("cymonline.core", package.seeall)

local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local json = require "luci.jsonc"
local nixio = require "nixio"
local fs = require "nixio.fs"

local NETWORK_SCRIPT = "/usr/lib/cymonline/network.sh"

-- ============================================================
-- Helper Functions
-- ============================================================

local function exec(cmd)
	local handle = io.popen(cmd .. " 2>/dev/null")
	if not handle then return "" end
	local result = handle:read("*a")
	handle:close()
	return result or ""
end

local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

local function mac_to_section(mac)
	-- Convert MAC to valid UCI section name (replace : with _)
	return mac:upper():gsub(":", "_")
end

local function section_to_mac(section)
	-- Convert UCI section name back to MAC
	return section:gsub("_", ":")
end

-- ============================================================
-- Device Detection
-- ============================================================

-- Get ARP table entries
local function get_arp_table()
	local arp = {}
	local f = io.open("/proc/net/arp", "r")
	if not f then return arp end

	for line in f:lines() do
		-- Skip header
		if not line:match("^IP") then
			local ip, hw, flags, mac, mask, dev = line:match(
				"(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)"
			)
			if ip and mac and mac ~= "00:00:00:00:00:00" then
				arp[mac:upper()] = {
					ip = ip,
					device = dev,
					flags = flags
				}
			end
		end
	end
	f:close()
	return arp
end

-- Get DHCP leases for hostname info
local function get_dhcp_leases()
	local leases = {}
	local lease_file = "/tmp/dhcp.leases"

	local f = io.open(lease_file, "r")
	if not f then return leases end

	for line in f:lines() do
		-- Format: timestamp mac ip hostname clientid
		local ts, mac, ip, hostname = line:match("(%d+)%s+(%S+)%s+(%S+)%s+(%S+)")
		if mac then
			mac = mac:upper()
			leases[mac] = {
				expires = tonumber(ts),
				ip = ip,
				hostname = (hostname ~= "*") and hostname or nil
			}
		end
	end
	f:close()
	return leases
end

-- Get saved device info from UCI
local function get_saved_devices()
	local devices = {}
	uci:foreach("cymonline", "device", function(s)
		local mac = s.mac
		if mac then
			mac = mac:upper()
			devices[mac] = {
				remark = s.remark or "",
				limit_up = tonumber(s.limit_up) or 0,
				limit_down = tonumber(s.limit_down) or 0
			}
		end
	end)
	return devices
end

-- Get all traffic stats at once
local function get_all_traffic_stats()
	local stats = {}
	local result = exec(NETWORK_SCRIPT .. " get_all_stats")
	if result and result ~= "" then
		for line in result:gmatch("[^\r\n]+") do
			local ip, rx, tx = line:match("(%S+)%s+(%d+)%s+(%d+)")
			if ip then
				stats[ip] = {
					rx = tonumber(rx) or 0,
					tx = tonumber(tx) or 0
				}
			end
		end
	end
	return stats
end

-- ============================================================
-- Public API
-- ============================================================

-- Get all devices (online + saved offline)
function get_devices()
	local arp = get_arp_table()
	local leases = get_dhcp_leases()
	local saved = get_saved_devices()
	local devices = {}

	-- Add traffic counters for online devices
	for mac, info in pairs(arp) do
		exec(NETWORK_SCRIPT .. " add_counter " .. info.ip)
	end

	-- Get all traffic stats at once
	local all_stats = get_all_traffic_stats()

	-- Process online devices
	for mac, arp_info in pairs(arp) do
		local lease = leases[mac] or {}
		local save = saved[mac] or {}
		local stat = all_stats[arp_info.ip] or { rx = 0, tx = 0 }

		devices[mac] = {
			mac = mac,
			ip = arp_info.ip,
			hostname = lease.hostname or "",
			online = true,
			rx_bytes = stat.rx,
			tx_bytes = stat.tx,
			remark = save.remark or "",
			limit_up = save.limit_up or 0,
			limit_down = save.limit_down or 0
		}
	end

	-- Add saved offline devices
	for mac, save in pairs(saved) do
		if not devices[mac] then
			local lease = leases[mac] or {}
			devices[mac] = {
				mac = mac,
				ip = "",
				hostname = lease.hostname or "",
				online = false,
				rx_bytes = 0,
				tx_bytes = 0,
				remark = save.remark,
				limit_up = save.limit_up,
				limit_down = save.limit_down
			}
		end
	end

	-- Convert to array
	local result = {}
	for mac, dev in pairs(devices) do
		table.insert(result, dev)
	end

	-- Sort: online first, then by IP
	table.sort(result, function(a, b)
		if a.online ~= b.online then
			return a.online
		end
		return (a.ip or "") < (b.ip or "")
	end)

	return result
end

-- Save device remark
function save_remark(mac, remark)
	mac = mac:upper()
	local section = mac_to_section(mac)

	-- Check if section exists
	local exists = false
	uci:foreach("cymonline", "device", function(s)
		if s.mac and s.mac:upper() == mac then
			exists = true
			uci:set("cymonline", s[".name"], "remark", remark)
		end
	end)

	-- Create new section if not exists
	if not exists then
		uci:section("cymonline", "device", section, {
			mac = mac,
			remark = remark,
			limit_up = "0",
			limit_down = "0"
		})
	end

	uci:commit("cymonline")
	return true
end

-- Set speed limit
function set_limit(mac, up_kbps, down_kbps)
	mac = mac:upper()
	local section = mac_to_section(mac)

	up_kbps = tonumber(up_kbps) or 0
	down_kbps = tonumber(down_kbps) or 0

	-- Update UCI
	local exists = false
	uci:foreach("cymonline", "device", function(s)
		if s.mac and s.mac:upper() == mac then
			exists = true
			uci:set("cymonline", s[".name"], "limit_up", tostring(up_kbps))
			uci:set("cymonline", s[".name"], "limit_down", tostring(down_kbps))
		end
	end)

	if not exists then
		uci:section("cymonline", "device", section, {
			mac = mac,
			remark = "",
			limit_up = tostring(up_kbps),
			limit_down = tostring(down_kbps)
		})
	end

	uci:commit("cymonline")

	-- Apply tc rules
	exec(NETWORK_SCRIPT .. " set_limit " .. mac .. " " .. up_kbps .. " " .. down_kbps)

	return true
end

-- Delete device record
function delete_device(mac)
	mac = mac:upper()

	-- Remove speed limit first
	exec(NETWORK_SCRIPT .. " remove_limit " .. mac)

	-- Find and delete UCI section
	uci:foreach("cymonline", "device", function(s)
		if s.mac and s.mac:upper() == mac then
			uci:delete("cymonline", s[".name"])
		end
	end)

	uci:commit("cymonline")
	return true
end

-- Get settings
function get_settings()
	local interval = uci:get("cymonline", "main", "interval") or "5"
	return {
		interval = tonumber(interval)
	}
end

-- Save settings
function save_settings(interval)
	uci:set("cymonline", "main", "interval", tostring(interval))
	uci:commit("cymonline")
	return true
end
