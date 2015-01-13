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

local async = require('rphillips/async')
local fs = require('fs')
-- TODO CRYPTO
local errors = require('virgo/errors')

local function verify(path, sig_path, kpub_data, callback)
  local parallel = {
    hash = function(callback)
      local hash = crypto.verify.new('sha256')
      local stream = fs.createReadStream(path)
      stream:on('data', function(d)
        hash:update(d)
      end)
      stream:on('end', function()
        callback(nil, hash)
      end)
      stream:on('error', callback)
    end,
    sig = function(callback)
      fs.readFile(sig_path, callback)
    end
  }
  async.parallel(parallel, function(err, res)
    if err then
      return callback(err)
    end
    local hash = res.hash[1]
    local sig = res.sig[1]
    local pub_data = kpub_data
    local key = crypto.pkey.from_pem(pub_data)

    if not key then
      return callback(errors.InvalidSignatureError:new('invalid key file'))
    end

    if not hash:final(sig, key) then
      return callback(errors.InvalidSignatureError:new('invalid sig on file: '.. path))
    end

    callback()
  end)
end

local exports = {}
exports.verify = verify
return exports
