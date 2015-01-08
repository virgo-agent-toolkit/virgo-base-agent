local MachineIdentity = require('virgo/machineidentity').MachineIdentity

require('tap')(function(test)
  test('MachineIdentity callback', function(expect)
    local function onGet() end
    MachineIdentity:new({}):get(expect(onGet))
  end)
end)
