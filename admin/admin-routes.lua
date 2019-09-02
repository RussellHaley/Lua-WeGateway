local c = {}

c.websocket_receive = function(self, Sessions, session, data)
	session.websocket:send("Got here!")
end

c.new = function() end
return c
