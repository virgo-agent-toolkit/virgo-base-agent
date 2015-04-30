--[[
Copyright 2014 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local async = require('async')
local fs = require('fs')
local openssl = require('openssl')
local errors = require('../errors')

local function verify(path, sig_path, kpub_data, callback)
  local parallel = {
    data = function(callback)
      local buffers = {}
      local stream = fs.createReadStream(path)
      stream:on('data', function(data)
        table.insert(buffers, data)
      end)
      stream:on('end', function()
        callback(nil, table.concat(buffers))
      end)
    end,
    sig = function(callback)
      local buffers = {}
      local stream = fs.createReadStream(sig_path)
      stream:on('data', function(data)
        table.insert(buffers, data)
      end)
      stream:on('end', function()
        callback(nil, table.concat(buffers))
      end)
    end
  }
  async.parallel(parallel, function(err, res)
    if err then
      return callback(err)
    end
    local data = res.data[1]
    local sig = res.sig[1]
    local pub_data = kpub_data
    local key = openssl.pkey.read(pub_data)
    if not key then
      return callback(errors.InvalidSignatureError:new('invalid key file'))
    end
    local rv = key:verify(data, sig, 'sha256') 
    if not rv then
      return callback(errors.InvalidSignatureError:new('invalid sig on file: '.. path))
    end
    callback()
  end)
end

exports.verify = verify
