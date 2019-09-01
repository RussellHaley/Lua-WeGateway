local lfs = require "lfs"
local cqueues = require "cqueues"
local filename = "debug.log"

local cq = cqueues.new()

--~ cq:wrap(function()
	--~ local start = lfs.attributes(filename, "size")
	--~ if not start then
		--~ print('No file')
	--~ end
	--~ local file_text = ""
	--~ local file = io.open(filename, "r")
	--~ if file and start < 100000 then
		--~ print(file:read("*a"))
	--~ elseif file and start >= 100000 then
		--~ print("file too big, truncate to x lines.")
	--~ end
	--~ --PRINT THE FILE
	--~ repeat
		--~ local sz = lfs.attributes(filename, "size")
		--~ local change = sz - start
		--~ if  change > 0 then
		--~ print(file:read("*a"))
		--~ file:read(sz) 
		--~ print("file grew")
		--~ --FILE SEEK, read unread bytes
		--~ elseif change < 0 then
		--~ print("file truncated.")
		--~ --FILE SEEK to new sz, read bytes
		--~ end
		--~ start = sz
		--~ --SLEEP
	--~ until the_end
--~ end);
cq:wrap(function()
	local filename = "debug.log"
	local file = io.open(filename, "r")
	print(file:read("*a"))
	--PRINT THE FILE
	repeat
		local data =  file:read("*a")
		if data and data ~= "" then
			print(data)
		end
		--SLEEP
		cqueues.sleep(2.5)
	until the_end
end);

local cq_ok, err, errno = cq:loop()
if not cq_ok then
	--~ logger:fatal("%d - %s\n%s", errno or -1, err or 'none', debug.traceback())
	print(err, errno, "Jumped the loop.", debug.traceback())
end



--[[
lfs find file
lfs get file size

file open
file seek (end - x bytes or lines?)
read
lfs get file size
begin file size - end file size
file seek (end - x bytes
sleep
--]]
