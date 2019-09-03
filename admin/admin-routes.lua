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


local function polling_event(self)
	local filename = "debug.log"
	local file = io.open(filename, "r")
	--Er, how do we get this session object?
	--~ session.websocket:send(file:read("*a"))
	local data = file:read("*a")
	polling_delegate(self, data)
	repeat
		data =  file:read("*a")
		if data and data ~= "" then
			--Why am I getting extra whitespace in stdout?
			--~ session.websocket:send(data))
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
