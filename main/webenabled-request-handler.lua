local dkjson = require "dkjson"
local serpent = require "serpent"
local Sessions, connection_log, logger


local uuid = require "uuid"
local function get_uuid()
	local u = uuid()
	return u
end


local function validate_set_session(self, session, msg)
	local Clients = {["Tel-Array"]=true,["Canary"]=true}
	local Models = {["A-1001"]=true}
	local result = false
	print("msg")
	print(serpent.block(msg), type(msg))
	local msgfmt = "Session: %s, field: %s, failure: %s, value: %s, type: %s"
	if msg.client and type(msg.client) == 'string' then
		if Clients[msg.client] then
			session.client = msg.client
			result = true
		else
		--client not found
			self.logger:info(msgfmt, session, "client", "client not found", msg.client, type(msg.client))			
			result = false
		end
	else
		--log and disconnect
		self.logger:info(msgfmt, session, "client", "bad format", msg.client, type(msg.client))
		result = false
	end

	if msg.model and type(msg.model) == 'string' then
		if Models[msg.model] then
			session.model = msg.model
			result = true
		else
			self.logger:info(msgfmt, session, "model", "model not found", msg.model, type(msg.model))
			--model not found
			result = false
		end
	else
		--model not specified
		self.logger:info(msgfmt, session, "model", "bad format", msg.model, type(msg.model))
		result = false
	end
	
	if msg.serial_number and type(msg.serial_number) == 'string' then
		session.serial_number = msg.serial_number
		result = true
	else
		---serial number not specified
		self.logger:info(msgfmt, session, "serial", "no serial or bad format", msg.serial, type(msg.serial_number))
		result = false
	end
	
	if msg.mode and type(msg.mode) == 'string' then
		if msg.mode == 'pair' or msg.mode == 'wait' then
			session.mode = msg.mode
			result = true
		else
			self.logger:info(msgfmt, session, "mode", "bad mode value", msg.mode, type(msg.mode))
			result = false
		end
	else
		self.logger:info(msgfmt, session, "mode", "bad format", msg.mode, type(msg.mode))
		result = false
	end
	if msg.pairing_key and msg.connection_id then 
		--bad message
		self.logger:info(msgfmt, session, "key", "too many keys", "na", "na")
		result = false
	end
	local pairing_key = tonumber(msg.pairing_key)
	if pairing_key and pairing_key < 100000 then
		session.pairing_key = msg.pairing_key
		result = true
	elseif msg.connection_id and type(msg.connection_id) =='string' then		
		session.connection_id = msg.connection_id
		result = true
	else
	--not a valid connection id
		result = false
		self.logger:info(msgfmt, session, "connection_id or pairing_key", 
			"bad format", msg.connection_id or msg.pairing_key, "na")		
	end
		
	return result
end


local function websocket_reply(self, Sessions, t, msg)

	if not msg.cmd then 
		t.websocket:send("Not Valid")
		return nil, "Not Valid", -1
	end
	local cmd = string.upper(msg.cmd)
	if cmd == 'CONNECT' then
		if not validate_set_session(self, t, msg) then			
			return nil, "Failed Validation", -2
		end
		self.logger:info("Passed Validation")
		print(t.mode)
		if t.mode == "wait" then
			--SET A TIMER
			self.logger:info("waiting")
			t.websocket:send("okay, waiting")
			return true
		elseif t.mode == "pair" then
			for i,v in pairs(Sessions) do
				if t.connection_id  then
					if t.connection_id == v.connection_id and t.session_id ~= v.session_id and v.mode == "wait" then
						--MATCH
						t.peer = i
						Sessions[i].peer = t.session_id
						local msg = "Thank you for choosing bell."
						t.websocket:send(msg)
						Sessions[i].websocket:send(msg)
						self.logger:info("wait peer: %s, pair peer: %s", Sessions[i].session_id, t.session_id)
						return true
					end
				elseif t.pairing_key then
					if t.pairing_key == v.pairing_key and t.session_id ~= v.session_id and v.mode == "wait" then
						--MATCH
						t.peer = i
						Sessions[i].peer = t.session_id
						--TURN TIMER OFF
						--GENERATE UUID
						local conn_id = get_uuid()
						--TURN THIS INTO REUTRNMESS
						t.websocket:send(conn_id)
						Sessions[i].websocket:send(conn_id)
						self.logger:info("wait peer: %s, pair peer: %s", Sessions[i].session_id, t.session_id)
						return true
					end
				end
			end			
		end
	else
		self.logger:error("Not a valid command")
		return nil, "Not a vaild command.", -3
	end
end



--- process_request is where we process the request from the client.
-- The system upgrades to a websocket if the ws or wss protocols are used.
-- @param server ?
-- @param An open stream to the client. Raw socket abstraction?
local function websocket_receive(self, Sessions, session, data)

--[[
get the users address and check if there is an existing session
if exists: set timestamp, check if authenticated.
else create new: timestamp of first contact, address, set auth to no.
--]]

	if session.peer then
		--SEND TO PEER
		if Sessions[session.peer] and Sessions[session.peer].websocket then
			Sessions[session.peer].websocket:send(data)
		else
			self.logger:error("No Peer, attempted to send")
			data = nil
		end
	else
		local msg, pos, err = dkjson.decode(data, 1, nil)
							
		if msg and type(msg) == 'table' then
			
			if DEBUG then
				self.logger:info(serpent.block(msg))
			end
			local ok, err, errno = websocket_reply(self, Sessions, session, msg)
			if not ok then
				self.logger:info(err, errno)
				session.websocket:close(1000, err or "Failed")
				data = nil
			end
		else
			print(type(data))
			print(type(msg))
			print(msg)
			self.logger:info("message could not be parsed")
			self.logger:info(pos, err)
			session.websocket:send(string.format("I only speak json, sorry. %s - %s", data, session.session_id))
		end
	end
end

local function new(debug_log )
	obj = {
		logger = debug_log, 
		websocket_receive = websocket_receive
	}
	return obj
end

return {new = new}
