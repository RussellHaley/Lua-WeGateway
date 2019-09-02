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
				output.value = "error: " .. wsMsg.error .. "\r\n" .. output.value
			else
				output.value = "message: " .. wsMsg .. "\r\n" .. output.value
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
		console.error("webSocket is not open: " .. webSocket.readyState)
	return
    end
    
    local jout = js.new(js.global.Object)
    jout.cmd = "connect"
    jout.client = document:getElementById("client").value
    jout.model = document:getElementById("model").value
    jout.serial_number = document:getElementById("serial").value
    jout.mode = document:getElementById("mode").value
    if document:getElementById("pairing_key") and document:getElementById("pairing_key").value ~= "" then
		jout.pairing_key = document:getElementById("pairing_key").value
    end
    if document:getElementById("connection_id") and document:getElementById("connection_id").value ~= "" then
		jout.connection_id = document:getElementById("connection_id").value
    end
    
    --~ local jout = JSON:MagicLuaConverter(out)
    local str = JSON:stringify(jout)
    webSocket:send(str)    
    print(str)    
end

local function onClearMessages()
	document:getElementById('incomingMsgOutput').value = "";
end

local btnConnect = document:getElementById('btnConnect')
   btnConnect.onclick=onConnectClick
local btnSend = document:getElementById('btnSend')
	btnSend.onclick=onSendClick
local btnSendCmd = document:getElementById('btnSendCmd')
	btnSendCmd.onclick=onSendCmdClick
local btnClear = document:getElementById('btnClear')
	btnclear.onclick=onClearMessages
