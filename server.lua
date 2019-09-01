#!/usr/local/bin/lua53

local gw = require('gateway')
local lfs = require "lfs"
local cqueues = require('cqueues')

--~ if config.tree == 'project' then dofile('init.lua') end

local function create_logger(cfg)
	local rolling_logger = require "logging.rolling_file"
	local logger = rolling_logger(cfg.base_path .. "/" .. cfg.debug_file_name, cfg.file_roll_size or 1024*1024*10, cfg.max_log_files or 31)
	if not logger then
		print("logger failed")
		os.exit(-1)
	end
	return logger
end
local function get_module_name(url)
  return url:match "(.*)%..*"
end


local function load_sites(cfg_dir, cq)
	for filename in lfs.dir(cfg_dir or "configs") do
		if filename ~= "." or filename ~= ".." then
			local stats = lfs.attributes(cfg_dir .. "/" .. filename)
			if stats.mode ~= "directory" then
				local module_name = filename:match "(.*)%..*"
				print(filename, module_name)
				--need to strip off the extension to make this happen
				local ws_config = require(cfg_dir.."."..module_name)
				cq:wrap(gw.new(create_logger(ws_config), ws_config))
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
	logger:fatal("%d - %s\n%s", errno or -1, err or 'none', debug.traceback())
	print(err, errno, "Jumped the loop.", debug.traceback())
end
