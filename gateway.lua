
--~ package.cpath = './lua_modules/lib/lua/5.3/?.so;./?.so'
--~ package.path = './lua_modules/share/lua/5.3/?.lua;./lua_modules/share/lua/5.3/?/init.lua;./lua_modules/share/lua/5.3/?.lua;./lua_modules/share/lua/5.3/?/init.lua;./?.lua;./?/init.lua'
--~ package.cpath = './lua_modules/lib/lua/5.3/?.so;./?.so'


--~ local cqueues = require "cqueues"
local request = require "http.request"
local http_server = require "http.server"
local websocket = require "http.websocket"
local http_headers = require "http.headers"
local new_headers = require "http.headers".new
local http_util = require "http.util"
local http_version = require "http.version"
local lpeg = require "lpeg"
local uri_patts = require "lpeg_patterns.uri"
local ce = require "cqueues.errno"
local rolling_logger = require "logging.rolling_file"
local dkjson = require "dkjson"
local uuid = require "uuid"
local lfs = require 'lfs'
local serpent = require "serpent"
local chronos = require 'chronos'

uuid.randomseed(12365843213246849613)
local req_timeout = 10
local ShutDown = false
local Sessions = {}
local uri_reference = uri_patts.uri_reference * lpeg.P(-1)
--~ local conf
local logger

--~ Placeholder for the function that writes websocke messages to the minecraft server.
--~  I can either use a scriptwide pty or a set the pty through a funciton in Run(). I chose the later.
local write_to_process

local connection_log

local function download_file(uri, dest, name)
	req = request.new_from_uri(uri)
	headers, stream = req:go(req_timeout)
	if headers then
		local name = dest..'/'.. name
		local file = io.open(name,'w')
		local ok = stream:save_body_to_file(file)
		return ok
	else
		--FREAKOUT
		return nil, 'failed to get the file'
	end

end

--- Get a UUID from the OS
-- return: Returns a system generated UUID
-- such as "4f1c1fbe-87a7-11e6-b146-0c54a518c15b"
local function get_uuid()
	local u = uuid()
	return u
end


local default_server = string.format("%s/%s", http_version.name, http_version.version)

local xml_escape do
	local escape_table = {
		["'"] = "&apos;";
		["\""] = "&quot;";
		["<"] = "&lt;";
		[">"] = "&gt;";
		["&"] = "&amp;";
	}
	function xml_escape(str)
		str = string.gsub(str, "['&<>\"]", escape_table)
		str = string.gsub(str, "[%c\r\n]", function(c)
			return string.format("&#x%x;", string.byte(c))
		end)
		return str
	end
end

local human do -- Utility function to convert to a human readable number
	local suffixes = {
		[0] = "";
		[1] = "K";
		[2] = "M";
		[3] = "G";
		[4] = "T";
		[5] = "P";
	}
	local log = math.log

	function human(n)
		if n == 0 then return "0" end
		local order = math.floor(log(n, 2) / 10)
		if order > 5 then order = 5 end
		n = math.ceil(n / 2^(order*10))
		return string.format("%d%s", n, suffixes[order])
	end
end


--[[
Static Reply
Does not recognize mime types associated with files
Does not serve index.html if the file exists, only servers directory
No templating
--]]
local function static_reply(myserver, stream, req_headers, static_dir, default_document) -- luacheck: ignore 212

	-- Read in headers
	assert(req_headers)
	local req_method = req_headers:get ":method"

	-- Build response headers
	local res_headers = new_headers()
	res_headers:append(":status", nil)
	res_headers:append("server", default_server)
	res_headers:append("date", http_util.imf_date())

	if req_method ~= "GET" and req_method ~= "HEAD" then
		res_headers:upsert(":status", "405")
		assert(stream:write_headers(res_headers, true))
		return
	end

	local path = req_headers:get(":path")
	local uri_t = assert(uri_reference:match(path), "invalid path")
	path = http_util.resolve_relative_path("/", uri_t.path)
	if path == "/" and default_document then 
		path = path .. default_document 
	end
	local real_path = static_dir .. path
	print(path, real_path)
	local file_type = lfs.attributes(real_path, "mode")
	print(string.format("file type: %s", file_type)) 
	if file_type == "directory" then
		--~ directory listing
		path = path:gsub("/+$", "") .. "/"
		res_headers:upsert(":status", "200")
		res_headers:append("content-type", "text/html; charset=utf-8")
		assert(stream:write_headers(res_headers, req_method == "HEAD"))
		if req_method ~= "HEAD" then

			assert(stream:write_chunk(string.format([[
<!DOCTYPE html>
<html>
<head>
	<title>Index of %s</title>
	<style>
		a {
			float: left;
		}
		a::before {
			width: 1em;
			float: left;
			content: "\0000a0";
		}
		a.directory::before {
			
			content: "\0000a0";
		}
		table {
			width: 800px;
		}
		td {
			padding: 0 5px;
			white-space: nowrap;
		}
		td:nth-child(2) {
			text-align: right;
			width: 3em;
		}
		td:last-child {
			width: 1px;
		}
	</style>
</head>
<body>
	<h1>Index of %s</h1>
	<table>
		<thead><tr>
			<th>File Name</th><th>Size</th><th>Modified</th>
		</tr></thead>
		<tbody>
]], xml_escape(path), xml_escape(path)), false))
			-- lfs doesn't provide a way to get an errno for attempting to open a directory
			-- See https://github.com/keplerproject/luafilesystem/issues/87
			for filename in lfs.dir(real_path) do
				if not (filename == ".." and path == "/") then -- Exclude parent directory entry listing from top level
					local stats = lfs.attributes(real_path .. "/" .. filename)
					if stats.mode == "directory" then
						filename = filename .. "/"
					end
					assert(stream:write_chunk(string.format("\t\t\t<tr><td><a class='%s' href='%s'>%s</a></td><td title='%d bytes'>%s</td><td><time>%s</time></td></tr>\n",
						xml_escape(stats.mode:gsub("%s", "-")),
						xml_escape(http_util.encodeURI(path .. filename)),
						xml_escape(filename),
						stats.size,
						xml_escape(human(stats.size)),
						xml_escape(os.date("!%Y-%m-%d %X", stats.modification))
					), false))
				end
			end
			assert(stream:write_chunk([[
		</tbody>
	</table>
</body>
</html>
]], true))
		end
	elseif file_type == "file" then
	
		local fd, err, errno = io.open(real_path, "rb")
		local code
		if not fd then
			if errno == ce.ENOENT then
				code = "404"
			elseif errno == ce.EACCES then
				code = "403"
			else
				code = "503"
			end
			res_headers:upsert(":status", code)
			res_headers:append("content-type", "text/plain")
			assert(stream:write_headers(res_headers, req_method == "HEAD"))
			if req_method ~= "HEAD" then
				assert(stream:write_body_from_string("Fail!\n"..err.."\n"))
			end
		else
			res_headers:upsert(":status", "200")
			--~res_headers:append("content-type", "text/plain")
			res_headers:append("content-type", "text/html")
			--~ local mime_type = mdb and mdb:file(real_path) or "application/octet-stream"
			--~ res_headers:append("content-type", mime_type)
			assert(stream:write_headers(res_headers, req_method == "HEAD"))
			if req_method ~= "HEAD" then
				assert(stream:write_body_from_file(fd))
			end
		end
	elseif file_type == nil then
	
		res_headers:upsert(":status", "404")
		assert(stream:write_headers(res_headers, true))
	else
		res_headers:upsert(":status", "403")
		assert(stream:write_headers(res_headers, true))
	end
end

local function validate_set_session(session, msg)
	local Clients = {["Tel-Array"]=true,["Canary"]=true}
	local Models = {["A-1001"]=true}
	local result = false
	print("msg")
	print(serpent.block(msg), type(msg))
	local msgfmt = "Session: %s, field: %s, failure: %s, value: %s, type: %s"
	if msg.client and type(msg.client) == 'string' then
		if Clients[msg.client] then
			session.client = msg.client
			result = true
		else
		--client not found
			logger:info(msgfmt, session, "client", "client not found", msg.client, type(msg.client))			
			result = false
		end
	else
		--log and disconnect
		logger:info(msgfmt, session, "client", "bad format", msg.client, type(msg.client))
		result = false
	end

	if msg.model and type(msg.model) == 'string' then
		if Models[msg.model] then
			session.model = msg.model
			result = true
		else
			logger:info(msgfmt, session, "model", "model not found", msg.model, type(msg.model))
			--model not found
			result = false
		end
	else
		--model not specified
		logger:info(msgfmt, session, "model", "bad format", msg.model, type(msg.model))
		result = false
	end
	
	if msg.serial_number and type(msg.serial_number) == 'string' then
		session.serial_number = msg.serial_number
		result = true
	else
		---serial number not specified
		logger:info(msgfmt, session, "serial", "no serial or bad format", msg.serial, type(msg.serial_number))
		result = false
	end
	
	if msg.mode and type(msg.mode) == 'string' then
		if msg.mode == 'pair' or msg.mode == 'wait' then
			session.mode = msg.mode
			result = true
		else
			logger:info(msgfmt, session, "mode", "bad mode value", msg.mode, type(msg.mode))
			result = false
		end
	else
		logger:info(msgfmt, session, "mode", "bad format", msg.mode, type(msg.mode))
		result = false
	end
	if msg.pairing_key and msg.connection_id then 
		--bad message
		logger:info(msgfmt, session, "key", "too many keys", "na", "na")
		result = false
	end
	local pairing_key = tonumber(msg.pairing_key)
	if pairing_key and pairing_key < 100000 then
		session.pairing_key = msg.pairing_key
		result = true
	elseif msg.connection_id and type(msg.connection_id) =='string' then		
		session.connection_id = msg.connection_id
		result = true
	else
	--not a valid connection id
		result = false
		logger:info(msgfmt, session, "connection_id or pairing_key", 
			"bad format", msg.connection_id or msg.pairing_key, "na")		
	end
		
	return result
end


local function websocket_reply(t, msg)

	if not msg.cmd then 
		t.websocket:send("Not Valid")
		return nil, "Not Valid", -1
	end
	local cmd = string.upper(msg.cmd)
	if cmd == 'CONNECT' then
		if not validate_set_session(t, msg) then			
			return nil, "Failed Validation", -2
		end
		logger:info("Passed Validation")
		print(t.mode)
		if t.mode == "wait" then
			--SET A TIMER
			logger:info("waiting")
			t.websocket:send("okay, waiting")
			return true
		elseif t.mode == "pair" then
			for i,v in pairs(Sessions) do
				if t.connection_id  then
					if t.connection_id == v.connection_id and t.session_id ~= v.session_id and v.mode == "wait" then
						--MATCH
						t.peer = i
						Sessions[i].peer = t.session_id
						local msg = "Thank you for choosing bell."
						t.websocket:send(msg)
						Sessions[i].websocket:send(msg)
						logger:info("wait peer: %s, pair peer: %s", Sessions[i].session_id, t.session_id)
						return true
					end
				elseif t.pairing_key then
					if t.pairing_key == v.pairing_key and t.session_id ~= v.session_id and v.mode == "wait" then
						--MATCH
						t.peer = i
						Sessions[i].peer = t.session_id
						--TURN TIMER OFF
						--GENERATE UUID
						local conn_id = get_uuid()
						--TURN THIS INTO REUTRNMESS
						t.websocket:send(conn_id)
						Sessions[i].websocket:send(conn_id)
						logger:info("wait peer: %s, pair peer: %s", Sessions[i].session_id, t.session_id)
						return true
					end
				end
			end			
		end
	else
		logger:error("Not a valid command")
		return nil, "Not a vaild command.", -3
	end
end

--- process_request is where we process the request from the client.
-- The system upgrades to a websocket if the ws or wss protocols are used.
-- @param server ?
-- @param An open stream to the client. Raw socket abstraction?
local function process_request(server, stream, static_dir, default_document)

--[[
get the users address and check if there is an existing session
if exists: set timestamp, check if authenticated.
else create new: timestamp of first contact, address, set auth to no.
--]]

	
	local request_headers = assert(stream:get_headers())
	local request_method = request_headers:get ":method"

	local id = get_uuid()
	--how do I get the client url and mac?
	connection_log:info(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s" ',
		id,
		request_headers:get(":method") or "",
		request_headers:get(":path") or "",
		stream.connection.version,
		request_headers:get("referer") or "-",
		request_headers:get("user-agent") or "-"
		));

	local ws = websocket.new_from_stream(stream, request_headers)
	if ws then
	
		local t = {}
		t.session_id = id
		local num, ip, port = stream:peername()	
		t.address = ip..":"..port	
		t.session_start = os.date()
		Sessions[t.session_id] = t
		t.new_connection = true
		t.websocket = ws
		assert(t.websocket:accept())
		assert(t.websocket:send("WebEnabled - 0.1.0"))
		t.websocket:send('{"authenticated":false}')
		--Get my name first
		--Send an Authenticate required message
		repeat
			local data, err, errno = t.websocket:receive()
			
			if data then			
				if t.peer then
					--SEND TO PEER
					if Sessions[t.peer] and Sessions[t.peer].websocket then
						Sessions[t.peer].websocket:send(data)
					else
						logger:error("No Peer, attempted to send")
						data = nil
					end
				else
					local msg, pos, err = dkjson.decode(data, 1, nil)
										
					if msg and type(msg) == 'table' then
						
						if DEBUG then
							logger:info(serpent.block(msg))
						end
						local ok, err, errno = websocket_reply(t, msg)
						if not ok then
							logger:info(err, errno)
							t.websocket:close(1000, err or "Failed")
							data = nil
						end
					else
						print(type(data))
						print(type(msg))
						print(msg)
						logger:info("message could not be parsed")
						logger:info(pos, err)
						ws:send(string.format("I only speak json, sorry. %s - %s", data, t.session_id))
					end
				end
			else
				logger:error(err, errno, "Recieve Failed")
				print('doh')
				--Add valid reason codes for the data to be nil?
			end

		until not data
		logger:info("removed " .. id)
		if t.mode == "wait" then
				--~ should provide a reason...
				if Sessions[t.peer] and Sessions[t.peer].websocket then
				Sessions[t.peer].websocket:close(1001,"Peer Closed")			
				Sessions[t.peer] = nil
				logger:info("closed peer")
			end
		end
		Sessions[t.session_id] = nil
	else
		static_reply(server, stream, request_headers, static_dir, default_document)
	end
end
	
local function Listen(app_server)

	-- Manually call :listen() so that we are bound before calling :localname()
	assert(app_server:listen())
	do
		local id, ip, port = app_server:localname()
		logger:info(string.format("Now listening on %s port %d\n", ip, port))
	end
	local cq_ok, err, errno = app_server:loop()
	if not cq_ok then
		logger:error(err, errno, "Http server process ended.", debug.traceback())
	else
		logger:info('Web server exited')
	end

end

local function CreateServer(debug_logger, config)
	logger = debug_logger

	connection_log = rolling_logger(config.base_path .. "/" .. config.connection_log, config.file_roll_size or 1024*1024*10, config.max_log_files or 31)

	local jar = 'WebEnabled'
	logger:info(string.format('Welcome to %s', jar))
	
	local out = io.stderr
	--~ cq = cqueues.new()

	local listen_dir = string.format("%s/%s", config.base_path or ".", config.static_dir or "www")
	local app_server = http_server.listen {
	host = config.host;
	port = config.port;
	onstream = function(server,stream) process_request(server,stream, listen_dir, config.default_document or "index.html") end;
	onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
		local msg = op .. " on " .. tostring(context) .. " failed"
		if err then
			msg = msg .. ": " .. tostring(err)
		end
		assert(io.stderr:write(msg, "\n"))
	end;
	}
	
	return function() Listen(app_server) end
end

-- call Run with pcall and if it dies, restart it. We can then add a proper handler in cqueues for signals

return {new = CreateServer}

