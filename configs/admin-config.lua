local c = {
	--~ remote_host = "192.168.1.5",

	--remote_host = "192.168.17.193",
	--~ remote_host = "localhost",
	secure = false,
	tree = 'root', --project,user,root
	debug_file_name = 'logs/admin_debug.log',
	connection_log = 'logs/admin_connection.log',
	host='localhost',
	port=8090,
	base_path = 'admin',
	static_dir = 'www',
	default_document = "admin-index.html",
	file_roll_size = 10485760,
	max_log_files=31
}

c.handler_module = "admin-routes"
return c
