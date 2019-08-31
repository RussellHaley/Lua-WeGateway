local js = require "js"
local window = js.global
local console = js.global.console
local document = window.document
local WebSocket = js.global.WebSocket
local JSON = js.global.JSON
local webSocket   = null
local ws_protocol = null
local ws_hostname = null
local ws_port     = null
local ws_endpoint = null

--~ /**
--~ * Event handler for clicking on button "Connect"
--~ */
function onConnectClick() 

    local ws_protocol = document:getElementById("protocol").value
    local ws_hostname = document:getElementById("hostname").value
    local ws_port     = document:getElementById("port").value
    --~ local ws_endpoint = document:getElementById("endpoint").value
    openWSConnection(ws_protocol, ws_hostname, ws_port)
end
--~ /**
--~ * Event handler for clicking on button "Disconnect"
--~ */
function onDisconnectClick() 
    webSocket:close()
end
--~ /**
--~ * Open a new WebSocket connection using the given parameters
--~ */
function openWSConnection(protocol, hostname, port)
    local webSocketURL = null
    webSocketURL = protocol .. "://" .. hostname .. ":" .. port
    --~ webSocketURL = "wss://echo.websocket.org"
    console:log("openWSConnection - Connecting to: " .. JSON:stringify(webSocketURL))
	webSocket = js.new(WebSocket, webSocketURL)
		webSocket.onopen = function(this, openEvent) 
	    console:log("WebSocket OPEN: " .. JSON:stringify(openEvent, null, 4))
	    document:getElementById("btnSend").disabled       = false
	    document:getElementById("btnConnect").disabled    = true
	    document:getElementById("btnDisconnect").disabled = false
	end
	webSocket.onclose = function (closeEvent) 
	    --~ console:log("WebSocket CLOSE: " + JSON:stringify(closeEvent, null, 4))
	    document:getElementById("btnSend").disabled       = true
	    document:getElementById("btnConnect").disabled    = false
	    document:getElementById("btnDisconnect").disabled = true
	end
	webSocket.onerror = function (this, errorEvent) 
	    console:log("WebSocket ERROR: " + JSON:stringify(errorEvent, null, 4))
	end
	--~ webSocket.onmessage = function (this, messageEvent)
	function webSocket:onmessage(messageEvent)
		if messageEvent then
			console:log(messageEvent)
			local wsMsg = messageEvent.data
			--~ console:log("WebSocket MESSAGE: " .. wsMsg)
			local output = document:getElementById("incomingMsgOutput")
			if (wsMsg.error) then			
				output.value = output.value .. "error: " .. wsMsg.error .. "\r\n"
			else
				output.value = output.value .. "message: " .. wsMsg .. "\r\n"
			end
		else
			console:log("messageEvent was nil")
		end
	end

end
--~ /**
--~ * Send a message to the WebSocket server
--~ */
function onSendClick() 
    if (webSocket.readyState ~= WebSocket.OPEN) then
		console.error("webSocket is not open: " + webSocket.readyState)
	return
    end
    local msg = document:getElementById("message").value
    --~ webSocket:send(JSON:stringify(out))
    webSocket:send(msg)
end

function onSendCmdClick() 
	print('click, click click. damn, no bullets')
    if (webSocket.readyState ~= WebSocket.OPEN) then
		console.error("webSocket is not open: " + webSocket.readyState)
	return
    end
    
    local out = {}
    out.client = document:getElementById("client").value
    out.model = document:getElementById("model").value
    out.serial = document:getElementById("serial").value
    if document:getElementById("pairing_key") then
		out.pairing_key = document:getElementById("pairing_key").value
    elseif document:getElementById("connection_id") then
		out.connection_id = document:getElementById("connection_id").value
    end
    --HOW TO CONVERT OUT TO JSON?
    --~ local jout = JSON:MagicLuaConverter(out)
    webSocket:send(JSON:stringify(jout))
    local jout = '{"cmd":"connect","client":"Sf","model":"mk1","serial":"9999","pairing_key":12345}'
    print(jout)
    webSocket:send(jout)
end

local btnConnect = document:getElementById('btnConnect')
   btnConnect.onclick=onConnectClick
local btnSend = document:getElementById('btnSend')
	btnSend.onclick=onSendClick
local btnSendCmd = document:getElementById('btnSendCmd')
	btnSendCmd.onclick=onSendCmdClick
