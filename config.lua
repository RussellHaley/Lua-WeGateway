local c = {
	--~ remote_host = "192.168.1.5",

	--remote_host = "192.168.17.193",
	--~ remote_host = "localhost",
	secure = false,
	tree = 'root', --project,user,root
	base_path = '.',
	debug_file_name = 'debug.log',
	connection_log = 'connection.log',
	host='localhost',
	port=8099,
	base_path = '.',
	static_dir = 'www',
	connection_log = 'connections.log',
	file_roll_size = 10485760,
	max_log_files=31
}


return c

