local cqueues = require("cqueues")
local c = {}

local function websocket_receive(self, Sessions, session, data)
	session.websocket:send("Got here!")
end


local function polling_delegate(self, data)
	for i,v in pairs(self.delegates) do
		v(data)
	end
end

function trim1(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function polling_event(self, filename)
	print(filename)
	if not filename and type(filename) == 'string' then 
		print("failed")
		return nil, "filename is a required parameter." 
	end
	local file = io.open(filename, "r")
	local data = file:read("*a")
	polling_delegate(self, data)
	repeat
		data =  file:read("*a")
		if data and data ~= "" then		
			--Send the data to the delegates (the session)
			polling_delegate(self, data)
		end
		--SLEEP
		cqueues.sleep(2.5)
	until the_end
end

local function register_handler(self, func)
	table.insert(self.delegates, func)
	return #self.delegates
end

local function remove_handler(self, func)
	for i,v in pairs(self.delegates) do
		if v == func then
			table.remove(self.delegates, i)
			return true
		end
	end
	return false
end

c.new = function(debug_log )
	obj = {
		logger = debug_log,
		delegates = {},
		websocket_receive = websocket_receive,
		polling_event = polling_event,
		register_handler = register_handler,
		remove_handler = remove_handler
	}
	return obj
end

return c
