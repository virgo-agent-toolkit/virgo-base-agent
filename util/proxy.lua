local net = require('net')
local url = require('url')
local http = require('http')
local https = require('https')
local Emitter = require('core').Emitter
local Error = require('core').Error

local Proxy = Emitter:extend()
function Proxy:initialize(options)
  self.options = options
end

function Proxy:connect(host, callback)
  local options = url.parse(self.options.proxy_url)
  local proto

  if options.protocol == 'http' then
    proto = http
  else
    proto = https
  end

  options.method = 'CONNECT'
  options.path = host
  options.headers = {
    ['connection'] = 'keep-alive',
  }

  local req
  req = proto.request(options, function(response)
    if response.status_code == 200 then
      callback(nil, req.socket)
    else
      callback(Error:new('Proxy Error'))
    end
  end)
  req:done()
end

local exports = {}
exports.Proxy = Proxy
return exports
