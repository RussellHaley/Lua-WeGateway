local c = {
	--~ remote_host = "192.168.1.5",

	--remote_host = "192.168.17.193",
	--~ remote_host = "localhost",
	secure = false,
	tree = 'root', --project,user,root
	debug_file_name = 'logs/debug.log',
	connection_log = 'logs/connections.log',
	host='192.168.1.110',
	port=8099,
	base_path = 'main',
	static_dir = 'www',
	file_roll_size = 10485760,
	max_log_files=31
}

c.websocket_receive = function(Sessions, session, data)
	--~ local send = session.websocket:send
	session.websocket:send("Hello Mr. "..session.session_id)
	session.websocket:send("Hi! Hi hi hi!")
end;


return c

