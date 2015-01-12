local Object = require('core').Object
local async = require('rphillips/async')
local dns = require('dns')
local fmt = require('string').format
local logging = require('rphillips/logging')
local math = require('math')
local misc = require('virgo/util/misc')

local Endpoint = Object:extend()

function Endpoint:initialize(host, port, srv_query)
  if not port and host then
    local ip_and_port = misc.splitAddress(host)
    host = ip_and_port[1]
    port = ip_and_port[2]
  end

  self.host = host
  self.port = port
  self.srv_query = srv_query
end


--[[
Determine the Hostname, IP and Port to use for this endpoint.

For static endpoints we just return our host and port, but for SRV
endpoints we query DNS.
--]]
function Endpoint:getHostInfo(callback)
  local ip, host, port

  async.series({
    function (callback)
      if self.srv_query then
        dns.resolve(self.srv_query, 'SRV', function(err, results)
          if err then
            logging.errorf('Could not lookup SRV record for %s', self.srv_query)
            callback(err)
            return
          end
          local r = results[ math.random(#results) ]
          host = r.name
          port = r.port
          logging.debugf('SRV:%s -> %s:%d', self.srv_query, host, port)
          callback()
        end)
      else
        host = self.host
        port = self.port
        callback()
      end
    end,
    function (callback)
      dns.lookup(host, function(err, ipa)
        if err then
          return callback(err)
        end
        ip = ipa
        callback()
      end)
    end
  },
  function(err)
    if (err) then
      return callback(err)
    end
    callback(nil, host, ip, port)
  end)

end

function Endpoint.meta.__tostring(table)
  if table.srv_query then
    return fmt("SRV:%s", table.srv_query)
  else
    return fmt("%s:%s", table.host, table.port)
  end
end

local exports = {}
exports.Endpoint = Endpoint
return exports
