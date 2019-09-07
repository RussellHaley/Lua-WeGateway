local c = {
	secure = false,
	tree = 'root', --project,user,root
	debug_file_name = 'logs/debug.log',
	connection_log = 'logs/connection.log',
	host='localhost',
	port=8090,
	base_path = 'admin',
	static_dir = 'www',
	default_document = "admin-index.html",
	file_roll_size = 10485760,
	max_log_files=31
}

c.handler_module = "admin-routes"
c.polling_file = "main/logs/debug.log"
return c
