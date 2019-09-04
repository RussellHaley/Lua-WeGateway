#!/usr/local/bin/lua53

local gateway = require('gateway')
local lfs = require "lfs"
local cqueues = require('cqueues')

local function create_logger(cfg)
	local path_and_name = cfg.base_path .. "/" .. cfg.debug_file_name
	local path = path_and_name:match("(.*[/\\])")	
	--mode returns "file" or "directory" if it exists, nil if not
	if not lfs.attributes(path, "mode") then
		assert(os.execute(string.format("mkdir -p %s", path)))		
	end
	local rolling_logger = require "logging.rolling_file"
	local logger = rolling_logger(path_and_name, cfg.file_roll_size or 1024*1024*10, cfg.max_log_files or 31)
	if not logger then
		print("logger failed")
		os.exit(-1)
	end
	return logger
end
local function get_module_name(url)
  return url:match "(.*)%..*"
end

-- need to load the site specific code from the configuration?
local function load_sites(cfg_dir, cq)
	for filename in lfs.dir(cfg_dir or "configs") do
		if filename ~= "." or filename ~= ".." then
			local stats = lfs.attributes(cfg_dir .. "/" .. filename)
			if stats.mode ~= "directory" then
				local module_name = filename:match "(.*)%..*"
				print(filename, module_name)
				--need to strip off the extension to make this happen
				local ws_config = require(cfg_dir.."."..module_name)
				local lgr = create_logger(ws_config)
				
				local h_file = nil
				local handlers = nil
				if ws_config.handler_module then
					print(ws_config.base_path.."."..ws_config.handler_module)
					h_file = ws_config.base_path.."."..ws_config.handler_module
					handlers = require(h_file).new(lgr)
				end
				--CHECK IF THE FILE EXISTS								
				print("Created Gateway:", handlers, ws_config.base_path)				
				local gw = gateway.new(ws_config, handlers, lgr)
				
				cq:wrap(gw.listen)
				if gw.handlers and gw.handlers.polling_event then
					cq:wrap(function() gw.handlers:polling_event() end)
				end
			end
		end
	end
end
local cq = cqueues.new()

configs = {}
cfg_dir = "configs"

load_sites(cfg_dir, cq)



local cq_ok, err, errno = cq:loop()
if not cq_ok then
	--~ logger:fatal("%d - %s\n%s", errno or -1, err or 'none', debug.traceback())
	print(err, errno, "Jumped the loop.", debug.traceback())
end
