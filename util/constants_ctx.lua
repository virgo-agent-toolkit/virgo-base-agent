local os = require('os')
local misc = require('./misc')
local path = require('path')
local Object = require('core').Object

local ConstantsCtx = Object:extend()

function ConstantsCtx:initialize()
    self.values = {}
end

function ConstantsCtx:get(name, default_value)
    if self.values[name] ~= nil then
        return self.values[name]
    elseif not self.isGlobal then
        -- if the constant does not locally exists, check the globalCtx
        local v = ConstantsCtx.globalCtx:get(name, default_value)
        return v
    else
        return default_value
    end
end

function ConstantsCtx:set(name, value)
    self.values[name] = value
end

function ConstantsCtx:setGlobal(name, value)
    self.globalCtx.values[name] = value
end

local globalCtx = ConstantsCtx:new()
globalCtx.isGlobal = true
ConstantsCtx.globalCtx = globalCtx


-- Setting 'core' constants

globalCtx:set('DEFAULT_CHANNEL', 'stable')

-- All intervals and timeouts are in milliseconds

globalCtx:set('CONNECT_TIMEOUT', 6000)
globalCtx:set('SOCKET_TIMEOUT', 10000)
globalCtx:set('HEARTBEAT_INTERVAL_JITTER_MULTIPLIER', 7)

globalCtx:set('UPGRADE_INTERVAL', 86400000) -- 24hrs
globalCtx:set('UPGRADE_INTERVAL_JITTER', 3600000) -- 1 hr

globalCtx:set('RATE_LIMIT_SLEEP', 5000)
globalCtx:set('RATE_LIMIT_RETURN_CODE', 2)

globalCtx:set('DATACENTER_FIRST_RECONNECT_DELAY', 41 * 1000) -- initial datacenter delay
globalCtx:set('DATACENTER_FIRST_RECONNECT_DELAY_JITTER', 37 * 1000) -- initial datacenter jitter

globalCtx:set('DATACENTER_RECONNECT_DELAY', 5 * 60 * 1000) -- max connection delay
globalCtx:set('DATACENTER_RECONNECT_DELAY_JITTER', 17 * 1000)

globalCtx:set('SRV_RECORD_FAILURE_DELAY', 13 * 1000)
globalCtx:set('SRV_RECORD_FAILURE_DELAY_JITTER', 37 * 1000)

globalCtx:set('SETUP_AUTH_TIMEOUT', 45 * 1000)
globalCtx:set('SETUP_AUTH_CHECK_INTERVAL', 2 * 1000)

globalCtx:set('SHUTDOWN_UPGRADE', 1)
globalCtx:set('SHUTDOWN_RATE_LIMIT', 2)
globalCtx:set('SHUTDOWN_RESTART', 3)

if misc.isStaging() then
  globalCtx:set('DEFAULT_MONITORING_SRV_QUERIES', {
    '_monitoringagent._tcp.dfw1.stage.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.ord1.stage.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.lon3.stage.monitoring.api.rackspacecloud.com'
  })

  globalCtx:set('SNET_MONITORING_TEMPLATE_SRV_QUERIES', {
      '_monitoringagent._tcp.snet-${region}-region0.stage.monitoring.api.rackspacecloud.com',
      '_monitoringagent._tcp.snet-${region}-region1.stage.monitoring.api.rackspacecloud.com',
      '_monitoringagent._tcp.snet-${region}-region2.stage.monitoring.api.rackspacecloud.com'
  })
else
  globalCtx:set('DEFAULT_MONITORING_SRV_QUERIES', {
    '_monitoringagent._tcp.dfw1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.ord1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.lon3.prod.monitoring.api.rackspacecloud.com'
  })

  globalCtx:set('SNET_MONITORING_TEMPLATE_SRV_QUERIES', {
    '_monitoringagent._tcp.snet-${region}-region0.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.snet-${region}-region1.prod.monitoring.api.rackspacecloud.com',
    '_monitoringagent._tcp.snet-${region}-region2.prod.monitoring.api.rackspacecloud.com'
  })

end

globalCtx:set('VALID_SNET_REGION_NAMES', {
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


globalCtx:set('DEFAULT_PERSISTENT_VARIABLE_PATH', path.join(PERSISTENT_DIR, 'variables'))
globalCtx:set('DEFAULT_CONFIG_PATH', path.join(CONFIG_DIR, 'rackspace-monitoring-agent.cfg'))
globalCtx:set('DEFAULT_STATE_PATH', path.join(RUNTIME_DIR, 'states'))
globalCtx:set('DEFAULT_DOWNLOAD_PATH', path.join(RUNTIME_DIR, 'downloads'))
globalCtx:set('DEFAULT_RUNTIME_PATH', RUNTIME_DIR)

globalCtx:set('DEFAULT_VERIFIED_BUNDLE_PATH', BUNDLE_DIR)
globalCtx:set('DEFAULT_UNVERIFIED_BUNDLE_PATH', path.join(globalCtx:get('DEFAULT_DOWNLOAD_PATH'), 'unverified'))
globalCtx:set('DEFAULT_VERIFIED_EXE_PATH', EXE_DIR)
globalCtx:set('DEFAULT_UNVERIFIED_EXE_PATH', path.join(globalCtx:get('DEFAULT_DOWNLOAD_PATH'), 'unverified'))
globalCtx:set('DEFAULT_PID_FILE_PATH', '/var/run/rackspace-monitoring-agent.pid')

-- Custom plugins related settings

globalCtx:set('DEFAULT_CUSTOM_PLUGINS_PATH', path.join(LIBRARY_DIR, 'plugins'))
globalCtx:set('DEFAULT_PLUGIN_TIMEOUT', 60 * 1000)
globalCtx:set('PLUGIN_TYPE_MAP', {string = 'string', int = 'int64', float = 'double', gauge = 'gauge'})

globalCtx:set('CRASH_REPORT_URL', 'https://monitoring.api.rackspacecloud.com/agent-crash-report')


local exports = {}
exports.ConstantsCtx = ConstantsCtx
return exports
