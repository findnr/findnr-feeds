module("vpnrss.transformer", package.seeall)

local json = require "luci.jsonc"
local nixio = require "nixio"
local util = require "luci.util"

-- =========================================================================
-- Helpers
-- =========================================================================

local function b64decode(str)
	if not str then return "" end
	-- URL safe replacements
	str = str:gsub("-", "+"):gsub("_", "/")
	return nixio.bin.b64decode(str)
end

local function b64encode(str)
	if not str then return "" end
	return nixio.bin.b64encode(str)
end

local function url_decode(s)
	return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function split(str, delimiter)
	if str == nil or str == '' then return {} end
	local result = {}
	for match in (str..delimiter):gmatch("(.-)"..delimiter) do
		table.insert(result, match)
	end
	return result
end

-- Simplified URL parser (scheme://user:pass@host:port/path?query#fragment)
local function parse_url(url)
	local res = {}
	local s, e, scheme = url:find("^([%w%.%+%-]+)://")
	if not s then return nil end
	res.scheme = scheme
	url = url:sub(e+1)

	local fragment_parts = split(url, "#")
	if #fragment_parts > 1 then
		res.fragment = url_decode(fragment_parts[2])
		url = fragment_parts[1]
	end

	local query_parts = split(url, "?")
	if #query_parts > 1 then
		res.query = {}
		for _, pair in ipairs(split(query_parts[2], "&")) do
			local k, v = pair:match("([^=]+)=(.*)")
			if k then res.query[k] = url_decode(v or "") end
		end
		url = query_parts[1]
	end

	local auth_host_port = url
	local auth_parts = split(auth_host_port, "@")
	local host_port_str = auth_host_port
	
	if #auth_parts > 1 then
		res.userinfo = auth_parts[1]
		host_port_str = auth_parts[2]
		
		-- Try user:pass
		local user_pass = split(res.userinfo, ":")
		if #user_pass > 0 then res.user = user_pass[1] end
		if #user_pass > 1 then res.pass = user_pass[2] end
	end
	
	-- Handle host:port
	-- Check for ipv6 [::1]:80
	local port_match = host_port_str:match("]:(%d+)$")
	if port_match then
		res.port = tonumber(port_match)
		res.host = host_port_str:match("^%[(.+)%]:%d+$")
	else
		local parts = split(host_port_str, ":")
		if #parts > 1 then
			res.port = tonumber(parts[#parts])
			table.remove(parts, #parts)
			res.host = table.concat(parts, ":")
		else
			res.host = host_port_str
			res.port = 443 -- default?
		end
	end
	
	return res
end

-- =========================================================================
-- Parsers
-- =========================================================================

local function parse_vmess(link)
	local b64 = link:gsub("vmess://", "")
	local str = b64decode(b64)
	if not str then return nil end
	
	local v = json.parse(str)
	if not v then return nil end
	
	return {
		type = "vmess",
		name = v.ps,
		server = v.add,
		port = tonumber(v.port),
		uuid = v.id,
		alterId = tonumber(v.aid) or 0,
		cipher = v.scy or "auto",
		network = v.net or "tcp",
		tls = (v.tls == "tls"),
		ws_path = v.path,
		ws_headers = { Host = v.host },
		sni = v.sni or v.host
	}
end

local function parse_vless(link)
	-- vless://uuid@host:port?query#name
	local u = parse_url(link)
	if not u then return nil end
	
	local q = u.query or {}
	return {
		type = "vless",
		name = u.fragment,
		server = u.host,
		port = u.port,
		uuid = u.user,
		network = q.type or "tcp",
		tls = (q.security == "tls" or q.security == "reality"),
		flow = q.flow,
		ws_path = q.path,
		ws_headers = { Host = q.host },
		sni = q.sni,
		fp = q.fp,
		pbk = q.pbk,
		sid = q.sid
	}
end

local function parse_trojan(link)
	-- trojan://pass@host:port?query#name
	local u = parse_url(link)
	if not u then return nil end
	
	local q = u.query or {}
	return {
		type = "trojan",
		name = u.fragment,
		server = u.host,
		port = u.port,
		password = u.user,
		network = q.type or "tcp",
		sni = q.sni or q.peer,
		skip_cert_verify = (q.allowInsecure == "1")
	}
end

local function parse_ss(link)
	-- ss://base64(method:password)@host:port#name
	-- or ss://base64(method:password@host:port)#name
	local name = ""
	if link:find("#") then
		local parts = split(link, "#")
		link = parts[1]
		name = url_decode(parts[2])
	end
	
	local body = link:gsub("ss://", "")
	local method, password, server, port

	-- Try to see if it is full base64
	if not body:find("@") then
		local decoded = b64decode(body)
		if decoded then
			-- method:password@host:port
			local parts = split(decoded, "@")
			if #parts == 2 then
				local mp = split(parts[1], ":")
				method = mp[1]
				password = mp[2]
				
				local hp = split(parts[2], ":")
				server = hp[1]
				port = tonumber(hp[2])
			end
		end
	else
		-- user:pass@host:port
		local parts = split(body, "@")
		local userinfo = parts[1]
		local hp = parts[2]
		
		-- userinfo might be base64
		local decoded_info = b64decode(userinfo)
		if decoded_info then userinfo = decoded_info end
		
		local mp = split(userinfo, ":")
		method = mp[1]
		password = mp[2]
		
		local hp_parts = split(hp, ":")
		server = hp_parts[1]
		port = tonumber(hp_parts[2])
	end
	
	if not server then return nil end
	
	return {
		type = "ss",
		name = name,
		server = server,
		port = port,
		cipher = method,
		password = password
	}
end

local function parse_hysteria2(link)
	-- hysteria2://password@host:port?query#name
	local u = parse_url(link)
	if not u then return nil end
	
	local q = u.query or {}
	return {
		type = "hysteria2",
		name = u.fragment,
		server = u.host,
		port = u.port,
		password = u.user, -- user is password in hy2
		sni = q.sni or q.peer,
		insecure = (q.insecure == "1" or q.allowInsecure == "1"),
		obfs = q.obfs,
		obfs_password = q["obfs-password"]
	}
end

local function parse_node(link)
	if link:find("^vmess://") then return parse_vmess(link) end
	if link:find("^vless://") then return parse_vless(link) end
	if link:find("^trojan://") then return parse_trojan(link) end
	if link:find("^ss://") then return parse_ss(link) end
	if link:find("^hysteria2://") then return parse_hysteria2(link) end
	return nil
end

-- =========================================================================
-- Exporters
-- =========================================================================

-- --- to_clash ---

local function node_to_clash(node)
	local p = {
		name = node.name,
		type = node.type,
		server = node.server,
		port = node.port,
	}
	
	if node.type == "vmess" then
		p.uuid = node.uuid
		p.alterId = node.alterId
		p.cipher = node.cipher
		p.tls = node.tls
		p.servername = node.sni
		p.network = node.network
		if node.network == "ws" then
			p["ws-opts"] = {
				path = node.ws_path,
				headers = node.ws_headers
			}
		end
	elseif node.type == "ss" then
		p.cipher = node.cipher
		p.password = node.password
	elseif node.type == "trojan" then
		p.password = node.password
		p.sni = node.sni
		p["skip-cert-verify"] = node.skip_cert_verify
	elseif node.type == "vless" then
		p.uuid = node.uuid
		p.tls = node.tls
		p.servername = node.sni
		p.network = node.network
		p.flow = node.flow
		if node.network == "ws" then
			p["ws-opts"] = {
				path = node.ws_path,
				headers = node.ws_headers
			}
		end
		-- Reality
		if node.pbk then
			p["client-fingerprint"] = node.fp
			p["reality-opts"] = {
				["public-key"] = node.pbk,
				["short-id"] = node.sid
			}
		end
	elseif node.type == "hysteria2" then
		p.password = node.password
		p.sni = node.sni
		p["skip-cert-verify"] = node.insecure
		if node.obfs then
			p.obfs = node.obfs
			p["obfs-password"] = node.obfs_password
		end
	end
	
	return p
end

function to_clash(raw_nodes)
	local proxies = {}
	local proxy_names = {}
	
	for _, n in ipairs(raw_nodes) do
		local p = parse_node(n.link)
		if p then
			if n.alias and n.alias ~= "" then p.name = n.alias end
			table.insert(proxies, node_to_clash(p))
			table.insert(proxy_names, p.name)
		end
	end
	
	local res = {}
	res.proxies = proxies
	res["proxy-groups"] = {
		{
			name = "PROXIES",
			type = "select",
			proxies = proxy_names
		},
		{
			name = "AUTO",
			type = "url-test",
			url = "http://www.gstatic.com/generate_204",
			interval = 300,
			proxies = proxy_names
		}
	}
	res.rules = {
		"MATCH,PROXIES"
	}
	
	-- Primitive YAML dumper
	local function dump(o, indent)
		indent = indent or ""
		local s = ""
		if type(o) == "table" then
			-- Check if array
			local is_array = (#o > 0)
			for k, v in pairs(o) do
				if is_array then
					s = s .. indent .. "- " .. dump(v, indent .. "  "):gsub("^%s+", "")
				else
					s = s .. indent .. k .. ": " .. dump(v, indent .. "  "):gsub("^%s+", "")
				end
			end
		elseif type(o) == "string" then
			s = s .. o .. "\n"
		elseif type(o) == "boolean" then
			s = s .. (o and "true" or "false") .. "\n"
		elseif type(o) == "number" then
			s = s .. o .. "\n"
		else 
			s = s .. "\n"
		end
		return s
	end
	
	-- We can't write a full YAML dumper effectively in 50 lines. 
	-- Strategy: Use json to dump, but Clash needs YAML.
	-- Actually, let's just use strict formatting for the known structure.
	
	local out = {
		"port: 7890",
		"allow-lan: true",
		"mode: rule",
		"log-level: info",
		"proxies:"
	}
	for _, p in ipairs(proxies) do
		-- Escape double quotes in node name to prevent YAML parsing errors
		local safe_name = p.name:gsub('"', '\\"')
		table.insert(out, string.format('  - name: "%s"', safe_name))
		table.insert(out, "    type: " .. p.type)
		table.insert(out, "    server: " .. p.server)
		table.insert(out, "    port: " .. p.port)
		if p.uuid then table.insert(out, "    uuid: " .. p.uuid) end
		if p.cipher then table.insert(out, "    cipher: " .. p.cipher) end
		if p.password then table.insert(out, "    password: " .. p.password) end
		if p.tls ~= nil then table.insert(out, "    tls: " .. (p.tls and "true" or "false")) end
		if p.servername then table.insert(out, "    servername: " .. p.servername) end
		if p.network then table.insert(out, "    network: " .. p.network) end
		if p.alterId then table.insert(out, "    alterId: " .. p.alterId) end
		if p.flow then table.insert(out, "    flow: " .. p.flow) end
		if p["ws-opts"] then
			table.insert(out, "    ws-opts:")
			if p["ws-opts"].path then table.insert(out, "      path: " .. p["ws-opts"].path) end
			if p["ws-opts"].headers and p["ws-opts"].headers.Host then
				table.insert(out, "      headers:")
				table.insert(out, "        Host: " .. p["ws-opts"].headers.Host)
			end
		end
		if p["reality-opts"] then
			table.insert(out, "    client-fingerprint: " .. (p["client-fingerprint"] or "chrome"))
			table.insert(out, "    reality-opts:")
			if p["reality-opts"]["public-key"] then
				table.insert(out, "      public-key: " .. p["reality-opts"]["public-key"])
			end
			if p["reality-opts"]["short-id"] then
				table.insert(out, "      short-id: " .. p["reality-opts"]["short-id"])
			end
		end
	end
	
	table.insert(out, "proxy-groups:")
	table.insert(out, "  - name: PROXIES\n    type: select\n    proxies:")
	for _, n in ipairs(proxy_names) do
		local safe_name = n:gsub('"', '\\"')
		table.insert(out, string.format('      - "%s"', safe_name))
	end
	table.insert(out, "  - name: AUTO\n    type: url-test\n    url: http://www.gstatic.com/generate_204\n    interval: 300\n    proxies:")
	for _, n in ipairs(proxy_names) do
		local safe_name = n:gsub('"', '\\"')
		table.insert(out, string.format('      - "%s"', safe_name))
	end
	
	table.insert(out, "rules:\n  - MATCH,PROXIES\n")
	return table.concat(out, "\n")
end

-- --- to_singbox ---

function to_singbox(raw_nodes)
	local outbounds = {}
	local tags = {}
	
	table.insert(outbounds, { type = "selector", tag = "select", outbounds = tags })
	table.insert(outbounds, { type = "urltest", tag = "auto", outbounds = tags })
	
	for _, n in ipairs(raw_nodes) do
		local p = parse_node(n.link)
		if p then
			if n.alias and n.alias ~= "" then p.name = n.alias end
			local o = {
				tag = p.name,
				server = p.server,
				server_port = p.port,
				type = p.type
			}
			
			if p.type == "vmess" then
				o.uuid = p.uuid
				o.security = p.cipher
				o.alter_id = p.alterId
				if p.network == "ws" then
					o.transport = { type = "ws", path = p.ws_path, headers = p.ws_headers }
				end
				if p.tls then o.tls = { enabled = true, server_name = p.sni } end
			elseif p.type == "vless" then
				o.uuid = p.uuid
				o.flow = p.flow
				if p.network == "ws" then
					o.transport = { type = "ws", path = p.ws_path, headers = p.ws_headers }
				end
				if p.tls then
					o.tls = { enabled = true, server_name = p.sni }
					if p.pbk then
						o.tls.reality = { enabled = true, public_key = p.pbk, short_id = p.sid }
						o.tls.utls = { enabled = true, fingerprint = p.fp or "chrome" }
					end
				end
			elseif p.type == "trojan" then
				o.password = p.password
				if p.tls == nil or p.tls == true then 
					o.tls = { enabled = true, server_name = p.sni } 
				end
			elseif p.type == "ss" then
				o.method = p.cipher
				o.password = p.password
				o.type = "shadowsocks" -- singbox uses 'shadowsocks' full name
			elseif p.type == "hysteria2" then
				o.password = p.password
				if p.obfs then
					o.obfs = { type = p.obfs, password = p.obfs_password }
				end
				if p.tls == nil or p.tls == true then
					o.tls = { enabled = true, server_name = p.sni, insecure = p.insecure }
				end
			end
			
			table.insert(outbounds, o)
			table.insert(tags, p.name)
		end
	end
	
	local res = {
		outbounds = outbounds
	}
	return json.stringify(res, true)
end

-- --- to_base64 ---

function to_base64(raw_nodes)
	local lines = {}
	for _, n in ipairs(raw_nodes) do
		-- Note: We just return the raw lines concatenated, 
		-- optionally updating the hash/remark if alias is provided.
		-- But for simplicity, we mostly just return the raw links or re-encode them.
		-- Modifying vmess JSON ps field is hard without decoding.
		-- Let's just return the raw link stored in config, BUT we should update the remarks if alias exists.
		
		local line = n.link
		local p = parse_node(line)
		if p and n.alias and n.alias ~= "" then
			-- Re-encode with new name
			if p.type == "vmess" then
				-- We decoded it in P, so we can re-encode
				local v = json.parse(b64decode(line:gsub("vmess://", "")))
				v.ps = n.alias
				line = "vmess://" .. b64encode(json.stringify(v))
			else
				-- vless/trojan/ss: update fragment
				-- This is tricky with regex, so we might skip it or do a simple replace
				if line:find("#") then
					line = line:gsub("#.*", "#" .. n.alias)
				else
					line = line .. "#" .. n.alias
				end
			end
		end
		table.insert(lines, line)
	end
	return b64encode(table.concat(lines, "\n"))
end

function to_surge(raw_nodes)
	-- Placeholder for Surge format
	-- Implementing full Surge support is tedious, return generic list for now
	return to_base64(raw_nodes)
end
