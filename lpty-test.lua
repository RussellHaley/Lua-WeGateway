local cqueues = require ("cqueues")
local lpty = require("lpty")
local lfs = require("lfs")

local function read_process(pty)
	Shutdown = false
	repeat
		local ok = pty:readok(1)
		if ok then
			local data = pty:read(1)

			--~ for i,v in pairs(Sessions) do
				--~ v.websocket:send(data)
			--~ end
			print( '*', data, data:len() )
		else
		  --Do nothing right now.
		end
		cqueues.sleep(1)
	until Shutdown
	--~ logger:info('Read pty exited.')
	print('Read pty exited.')
end



local function StartProcess(pty, file_path, file_name)
	--~ if not retries or type(retries) ~= 'number' then retries = 1 end
	
	local errmsg = string.format('Failed to start minecraft after %d attempts', retries or 1)
	if not file_path or not file_name then 
		local str = "Cannot start process without a path and file name."
		--~ logger:error(str)
		print(str)
		return nil, str
	end


	--~ local jar = check_fs_for_mc(file_path, file_name)
	--~ local jar = check_for_file(file_path, file_name) ** This doesn't exist yet
	local cur_dir = lfs.currentdir()
	lfs.chdir(file_path)
	local command = 'tail'
	--~ local args = {'-f'}
	--~ local ok = pty:startproc(command, table.unpack(args), file_name)

	local ok = pty:startproc(command, file_name.."jhkhk")
	lfs.chdir(cur_dir)
	if not ok then
		local str = "Failed to start pty"
		--~ logger:error(str)
		print(str)
	else 
		if not pty:hasproc() then
			local str = string.format('Failed to start Process: Path %s, jar file: %s', file_path, file_name)
			--~ logger:error(str)
			print(str)
		end
	end
	--~ logger:info('process started.')
	print('process started.')
	return true
end


local pty = lpty.new({raw_mode=true})
	if not pty then
		logger:fatal('Failed to start a pty.')
		os.exit(-1)
end

local cq = cqueues.new()
cq:wrap(function() 
			read_process(pty) 
end);

file_path = "/home/russellh/git/WebEnabled/logs/"
file_name = "debug.log"

cq:wrap(function()
	StartProcess(pty, file_path, file_name)
end);

local cq_ok, err, errno = cq:loop()
if not cq_ok then
	--~ logger:fatal("%d - %s\n%s", errno or -1, err or 'none', debug.traceback())
	print(err, errno, "Jumped the loop.", debug.traceback())
end
