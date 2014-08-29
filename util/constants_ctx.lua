local os = require('os')
local misc = require('./misc')
local path = require('path')
local Object = require('core').Object
local fmt = require('string').format

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

local PERSISTENT_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_PERSISTENT_DIR)
local EXE_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_EXE_DIR)
local CONFIG_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_CONFIG_DIR)
local LIBRARY_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_LIBRARY_DIR)
local RUNTIME_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_RUNTIME_DIR)
local BUNDLE_DIR = virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE_DIR)

globalCtx:set('DEFAULT_PERSISTENT_VARIABLE_PATH', path.join(PERSISTENT_DIR, 'variables'))
globalCtx:set('DEFAULT_CONFIG_PATH', path.join(CONFIG_DIR, fmt('%s.cfg', virgo.pkg_name)))
globalCtx:set('DEFAULT_STATE_PATH', path.join(RUNTIME_DIR, 'states'))
globalCtx:set('DEFAULT_DOWNLOAD_PATH', path.join(RUNTIME_DIR, 'downloads'))
globalCtx:set('DEFAULT_RUNTIME_PATH', RUNTIME_DIR)

globalCtx:set('DEFAULT_VERIFIED_BUNDLE_PATH', BUNDLE_DIR)
globalCtx:set('DEFAULT_UNVERIFIED_BUNDLE_PATH', path.join(globalCtx:get('DEFAULT_DOWNLOAD_PATH'), 'unverified'))
globalCtx:set('DEFAULT_VERIFIED_EXE_PATH', EXE_DIR)
globalCtx:set('DEFAULT_UNVERIFIED_EXE_PATH', path.join(globalCtx:get('DEFAULT_DOWNLOAD_PATH'), 'unverified'))
globalCtx:set('DEFAULT_PID_FILE_PATH', fmt('/var/run/%s.pid', virgo.pkg_name))

globalCtx:set('CRASH_REPORT_URL', '')

local exports = {}
exports.ConstantsCtx = ConstantsCtx
return exports
