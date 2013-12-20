local os = require('os')
local misc = require('./misc')
local path = require('path')
local Object = require('core').Object

local Constants = Object:extend()

function Constants:initialize()
    self.values = {}
end

function Constants:Get(name, default_value)
    if self.values[name] ~= nil then
        return self.values[name]
    elseif not self.isGlobal then
        -- if the constant does not locally exists, check the globalCtx
        local v = Constants.globalCtx:Get(name, default_value)
        return v
    else
        return default_value
    end
end

function Constants:Set(name, value)
    self.values[name] = value
end

function Constants:SetGlobal(name, value)
    self.globalCtx.values[name] = value
end

local globalCtx = Constants:new()
globalCtx.isGlobal = true
Constants.globalCtx = globalCtx


-- Setting 'core' constants

globalCtx:Set('DEFAULT_CHANNEL', 'stable')

-- All intervals and timeouts are in milliseconds

globalCtx:Set('CONNECT_TIMEOUT', 6000)
globalCtx:Set('SOCKET_TIMEOUT', 10000)
globalCtx:Set('HEARTBEAT_INTERVAL_JITTER_MULTIPLIER', 7)

globalCtx:Set('UPGRADE_INTERVAL', 86400000) -- 24hrs
globalCtx:Set('UPGRADE_INTERVAL_JITTER', 3600000) -- 1 hr

globalCtx:Set('RATE_LIMIT_SLEEP', 5000)
globalCtx:Set('RATE_LIMIT_RETURN_CODE', 2)

globalCtx:Set('DATACENTER_FIRST_RECONNECT_DELAY', 41 * 1000) -- initial datacenter delay
globalCtx:Set('DATACENTER_FIRST_RECONNECT_DELAY_JITTER', 37 * 1000) -- initial datacenter jitter

globalCtx:Set('DATACENTER_RECONNECT_DELAY', 5 * 60 * 1000) -- max connection delay
globalCtx:Set('DATACENTER_RECONNECT_DELAY_JITTER', 17 * 1000)

globalCtx:Set('SRV_RECORD_FAILURE_DELAY', 13 * 1000)
globalCtx:Set('SRV_RECORD_FAILURE_DELAY_JITTER', 37 * 1000)

globalCtx:Set('SETUP_AUTH_TIMEOUT', 45 * 1000)
globalCtx:Set('SETUP_AUTH_CHECK_INTERVAL', 2 * 1000)

globalCtx:Set('SHUTDOWN_UPGRADE', 1)
globalCtx:Set('SHUTDOWN_RATE_LIMIT', 2)
globalCtx:Set('SHUTDOWN_RESTART', 3)

if misc.isStaging() then
  globalCtx:Set('DEFAULT_MONITORING_SRV_QUERIES', {
    '_monitoringagent._tcp.dfw1.stage.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.ord1.stage.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.lon3.stage.monitoring.api.rackspacecloud.com'
  })

  globalCtx:Set('SNET_MONITORING_TEMPLATE_SRV_QUERIES', {
      '_monitoringagent._tcp.snet-${region}-region0.stage.monitoring.api.rackspacecloud.com',
      '_monitoringagent._tcp.snet-${region}-region1.stage.monitoring.api.rackspacecloud.com',
      '_monitoringagent._tcp.snet-${region}-region2.stage.monitoring.api.rackspacecloud.com'
  })
else
  globalCtx:Set('DEFAULT_MONITORING_SRV_QUERIES', {
    '_monitoringagent._tcp.dfw1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.ord1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.lon3.prod.monitoring.api.rackspacecloud.com'
  })

  globalCtx:Set('SNET_MONITORING_TEMPLATE_SRV_QUERIES', {
    '_monitoringagent._tcp.snet-${region}-region0.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.snet-${region}-region1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.snet-${region}-region2.prod.monitoring.api.rackspacecloud.com'
  })

end

globalCtx:Set('VALID_SNET_REGION_NAMES', {
  'dfw',
  'ord',
  'lon',
  'syd',
  'hkg',
  'iad'
})


local PERSISTENT_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_PERSISTENT_DIR)
local EXE_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_EXE_DIR)
local CONFIG_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_CONFIG_DIR)
local LIBRARY_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_LIBRARY_DIR)
local RUNTIME_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_RUNTIME_DIR)
local BUNDLE_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE_DIR)


globalCtx:Set('DEFAULT_PERSISTENT_VARIABLE_PATH', path.join(PERSISTENT_DIR, 'variables'))
globalCtx:Set('DEFAULT_CONFIG_PATH', path.join(CONFIG_DIR, 'rackspace-monitoring-agent.cfg'))
globalCtx:Set('DEFAULT_STATE_PATH', path.join(RUNTIME_DIR, 'states'))
globalCtx:Set('DEFAULT_DOWNLOAD_PATH', path.join(RUNTIME_DIR, 'downloads'))
globalCtx:Set('DEFAULT_RUNTIME_PATH', RUNTIME_DIR)

globalCtx:Set('DEFAULT_VERIFIED_BUNDLE_PATH', BUNDLE_DIR)
globalCtx:Set('DEFAULT_UNVERIFIED_BUNDLE_PATH', path.join(globalCtx:Get('DEFAULT_DOWNLOAD_PATH'), 'unverified'))
globalCtx:Set('DEFAULT_VERIFIED_EXE_PATH', EXE_DIR)
globalCtx:Set('DEFAULT_UNVERIFIED_EXE_PATH', path.join(globalCtx:Get('DEFAULT_DOWNLOAD_PATH'), 'unverified'))
globalCtx:Set('DEFAULT_PID_FILE_PATH', '/var/run/rackspace-monitoring-agent.pid')

-- Custom plugins related settings

globalCtx:Set('DEFAULT_CUSTOM_PLUGINS_PATH', path.join(LIBRARY_DIR, 'plugins'))
globalCtx:Set('DEFAULT_PLUGIN_TIMEOUT', 60 * 1000)
globalCtx:Set('PLUGIN_TYPE_MAP', {string = 'string', int = 'int64', float = 'double', gauge = 'gauge'})

globalCtx:Set('CRASH_REPORT_URL', 'https://monitoring.api.rackspacecloud.com/agent-crash-report')


local exports = {}
exports.Constants = Constants
return exports
