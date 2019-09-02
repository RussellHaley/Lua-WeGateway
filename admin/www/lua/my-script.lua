local js = require "js"
local window = js.global
local document = window.document
local md5 = require 'lua.plc.md5'


print("Document's title: " .. document.title)
print('Hello from Lua')
print('Testing md5: ' .. md5.hash('This is a test of plc'))
local ep = document:getElementById('endpoint')
document.title = 'heads up friends!'
if ep then ep.value = 'look at me ma!' end


