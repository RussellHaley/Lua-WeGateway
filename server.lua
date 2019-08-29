#!/usr/local/bin/lua53

local gw = require('gateway')
local config = require 'config'
--~ local json = require 'json'
--~ local base64 = require 'base64'
local cqueues = require('cqueues')

local _encoded = nil
if config.tree == 'project' then dofile('init.lua') end
local rolling_logger = require "logging.rolling_file"

local logger = rolling_logger(config.base_path .. "/" .. config.debug_file_name, config.file_roll_size or 1024*1024*10, config.max_log_files or 31)
if not logger then
	print("logger failed")
	os.exit(-1)
end

cq = cqueues.new()

local listen = gw.new(logger, config)
cq:wrap(listen)

local cq_ok, err, errno = cq:loop()
if not cq_ok then
	logger:fatal("%d - %s\n%s", errno or -1, err or 'none', debug.traceback())
	print(err, errno, "Jumped the loop.", debug.traceback())
end
