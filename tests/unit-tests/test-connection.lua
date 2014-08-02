local Connection = require('../../libs/connection')
local stream = require('/base/modules/stream')
local test = require('/base/modules/tape')('connection')
local tls = require('tls')
local core = require('core')

test('Connection is stream.Duplex', nil, function(t)
  local connection = Connection:new(nil, {
    endpoint = {
      host = 'localhost',
      port = 12345,
    },
    agent = {
      token = 'this_is_a_token',
      id = '1',
    },
  })
  t:equal(true, core.instanceof(connection, stream.Duplex))
end)
