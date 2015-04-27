local fs = require('fs')
local util = require('../util/upgrade')
require('tap')(function(test)
  test('test validation', function(expect)
    local key = fs.readFileSync('tests/ca/server.crt')
    util.verify('tests/upgrades/input1.txt',
                'tests/upgrades/input1.txt.sig', key, expect(function(err)
      assert(not err)
    end))
  end)

  test('test invalid validation', function(expect)
    local key = fs.readFileSync('tests/ca/server.crt')
    util.verify('tests/upgrades/input1.txt',
                'tests/upgrades/input1.txt.sig.invalid', key, expect(function(err)
      assert(err, err)
    end))
  end)
end)
