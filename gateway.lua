
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
local conf
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


local function static_reply(myserver, stream, req_headers) -- luacheck: ignore 212

	-- Read in headers
	assert(req_headers)
	local req_method = req_headers:get ":method"

	-- Log request to stdout
	--[[assert(io.stdout:write(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s"\n',
		os.date("%d/%b/%Y:%H:%M:%S %z"),
		req_method or "",
		req_headers:get(":path") or "",
		stream.connection.version,
		req_headers:get("referer") or "-",
		req_headers:get("user-agent") or "-"
	)))--]]

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
	local real_path = conf.static_dir .. path
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


local function websocket_reply(t, msg)
--~ //Parse out the return socket name
print(msg)
	if not msg.cmd then 
		t.websocket:send("Need a command: {cmd:'?'}")
		return
	end
	local cmd = string.upper(msg.cmd)
	if cmd == 'MY_NAME_IS' then
		if not msg.name then  
			t.websocket:send("Need a name for the name commsnd: {cmd:'my_name_is', name:'?'}")
		else
			t.name = msg.name
			t.websocket:send("okay, I'll call you"..t.name)
		end
	elseif cmd == 'AUTHENTICATE' then 
		t.websocket:send("We're not there yet")
	elseif cmd == 'SEND' then
		if msg.recipient then
			for i,v in pairs(Sessions) do
				if v.name and v.name == msg.recipient then 
					Sessions[i].websocket:send(dkjson.encode(msg))
				end
			end
		end
	end
	--~ if msg.cmd then
		--~ local cmd = msg.cmd:upper()

		--~ if cmd == "STATUS" then

			--~ --Log status for each client
		--~ elseif cmd == "AUTH" then

		--~ elseif cmd == "HELP" then
			--~ write_to_process(msg.cmd..'\n')
		--~ elseif cmd == "UNIT-RESPONSE" then
		--~ else
			--~ logger:info("Type=" .. msg.cmd)
			--~ write_to_process(msg.cmd..'\n')
		--~ end
	--~ end
end


--- process_request is where we process the request from the client.
-- The system upgrades to a websocket if the ws or wss protocols are used.
-- @param server ?
-- @param An open stream to the client. Raw socket abstraction?
local function process_request(server, stream)

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
		--~ t.peer = stream:peername()
		local num, ip, port = stream:peername()		
		t.session_start = os.date()
		Sessions[ip..":"..port] = t
		t.new_connection = true
		t.websocket = ws
		assert(ws:accept())
		assert(ws:send("Welcome To exb Server"))
		assert(ws:send("Your client id is " .. t.session_id))
		ws:send("{authenticated:false}")
		--Get my name first
		--Send an Authenticate required message
		repeat
			local data, err, errno = ws:receive()
			if data then
				local msg, pos, err = dkjson.decode(data, 1, nil)
									
				if msg and type(msg) == 'table' then
					
					if DEBUG then
						logger:info(serpent.block(msg))
					end
					websocket_reply(t, msg)
				else
					print(type(data))
					print(type(msg))
					print(msg)
					logger:info("message could not be parsed")
					logger:info(pos, err)
					ws:send(string.format("I only speak json, sorry. %s - %s", data, t.session_id))
				end
			else
				print('doh')
				--Add valid reason codes for the data to be nil?
				if errno == 1 then

				else
					logger:error(err, errno, "Recieve Failed")
				end
			end

		until not data
		logger:info("removed " .. id)
		Sessions[id] = nil
	else
		static_reply(server, stream, request_headers)
	end
end
	
local function Listen(app_server)

	-- Manually call :listen() so that we are bound before calling :localname()
	assert(app_server:listen())
	do
		
		logger:info(string.format("Now listening on %s port %d\n", app_server:localname(), conf.port))
	end
	local cq_ok, err, errno = app_server:loop()
	if not cq_ok then
		logger:error(err, errno, "Http server process ended.", debug.traceback())
	else
		logger:info('Web server exited')
	end

end

local function CreateListen(debug_logger, config)
	logger = debug_logger
	conf = config
	connection_log = rolling_logger(conf.base_path .. "/" .. conf.connection_log, conf.file_roll_size or 1024*1024*10, conf.max_log_files or 31)

	local jar = 'we-client'
	logger:info(string.format('Welcome to %s', jar))
	
	local out = io.stderr
	--~ cq = cqueues.new()

	local app_server = http_server.listen {
	host = conf.host;
	port = conf.port;
	onstream = process_request;
	}
	
	return function() Listen(app_server) end
end

-- call Run with pcall and if it dies, restart it. We can then add a proper handler in cqueues for signals

return {new = CreateListen}

