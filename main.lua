--[[

Copyright 2014 Rackspace. All Rights Reserved.

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

_G.virgo = {}
_G.virgo.virgo_version = '2.0.0'
_G.virgo.bundle_version = _G.virgo.virgo_version

local luvi = require('luvi')
local bundle = luvi.bundle

-- Manually register the require replacement system to bootstrap things
bundle.register("require", "modules/require.lua");
-- Upgrade require system in-place
_G.require = require('require')()("bundle:main.lua")

local app = require('..')
app.init()

local uv = require('uv')

local combo = nil
local script = nil
local extra = {}

for i = 1, #args do
  local arg = args[i]
  if script then
    extra[#extra + 1] = arg
  elseif combo then
    combo(arg)
    combo = nil
  elseif string.sub(arg, 1, 1) == "-" then
    local flag
    if (string.sub(arg, 2, 2) == "-") then
      flag = string.sub(arg, 3)
    else
      arg = string.sub(arg, 2)
      flag = shorts[arg] or arg
    end
    local fn = flags[flag] or usage
    fn()
  else
    script = arg
  end
end

if script then
  require(luvi.path.join(uv.cwd(), script))
end

app.run()

return 0
