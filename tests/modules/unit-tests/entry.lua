-- this file is used to provide an entry point compliant with current
-- rackspace-monitoring-agent binary that runs luvit-tape tests

local function run()
  require('./test-connection')
end

exports.run = run
