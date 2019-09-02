local c = {}

local function websocket_receive(self, Sessions, session, data)
	session.websocket:send("Got here!")
end

c.new = function(debug_log )
	obj = {
		logger = debug_log, 
		websocket_receive = function(self, Sessions, session, data)
				session.websocket:send("Got here!")
				end;
	}
	return obj
end
return c
