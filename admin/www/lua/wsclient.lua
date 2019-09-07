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
	    document:getElementById("btnConnect").disabled    = true
	    document:getElementById("btnDisconnect").disabled = false
	end
	webSocket.onclose = function (closeEvent) 
	    --~ console:log("WebSocket CLOSE: " + JSON:stringify(closeEvent, null, 4))
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
				output.value = wsMsg .. output.value
			end
		else
			console:log("messageEvent was nil")
		end
	end

end

local function onClearMessages()
	document:getElementById('incomingMsgOutput').value = "";
end

local btnConnect = document:getElementById('btnConnect')
   btnConnect.onclick=onConnectClick
local btnClear = document:getElementById('btnClear')
	btnClear.onclick=onClearMessages
