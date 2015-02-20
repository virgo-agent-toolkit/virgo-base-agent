--[[
Copyright 2013-2015 Rackspace

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
local MachineIdentity = require('../machineidentity').MachineIdentity

require('tap')(function(test)
  test('MachineIdentity callback', function(expect)
    local function onGet() end
    MachineIdentity:new({}):get(expect(onGet))
  end)
end)
