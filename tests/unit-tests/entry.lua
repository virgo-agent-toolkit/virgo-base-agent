-- this file is used to provide an entry point compliant with current
-- rackspace-monitoring-agent binary that runs luvit-tape tests

local stats = require('/base/modules/tape/lib/stats')

return {
  run = function()
    process:once('exit', function(exit_code)
      if stats.failedTests ~= 0 then
        process.exit(1)
      end
    end)

    require('./test-connection')
  end
}
