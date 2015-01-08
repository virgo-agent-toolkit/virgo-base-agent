-- this file is used to provide an entry point compliant with current
-- rackspace-monitoring-agent binary that runs luvit-tape tests

local tap = require("tap")
local bundle = require('luvi').bundle

local function run()
  local files, match
  files = bundle.readdir('modules/unit-tests')
  for _, name in ipairs(files) do
    match = string.match(name, "^test%-(.*).lua$")
    if match then
      local path = "./test-" .. match
      tap(match)
      require(path)
    end
  end
  tap(true)
end

exports.run = run
