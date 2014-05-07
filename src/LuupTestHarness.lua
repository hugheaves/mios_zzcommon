-- MiOS Plugin Test Harness
--
-- Copyright (C) 2014 testcd   Hugh Eaves
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


-- IMPORT GLOBALS
local os = os
local log = require("L_" .. g_pluginName .. "_log")

-- IMPORT REQUIRED MODULES
local socket = require("socket")

-----------------------------
---- Globals ----------------
-----------------------------


-----------------------------
---- File Globals -----------
-----------------------------

local g_luupVariables = {}

local g_deviceVariableWatchers = {}

local g_globalVariableWatchers = {}

local g_callbackFunctions = {}

local g_functions = {}

local g_nextDeviceId = 1000

local g_devices = {}

-----------------------------
---- File Constants -----------
-----------------------------
--local LOG_CONFIG = {
--  ["version"] = 1,
--  ["files"] = {
--    ["./*LuupTestHarness.lua$"] = {
--      "log",
--      "getVariableTable"
--    }
--  }
--}

--------------------------------
---- Internal Functions --------
--------------------------------

local function initWatcherTables(service, lul_device, variable)
  if (not g_globalVariableWatchers[service]) then
    g_globalVariableWatchers[service] = {}
  end
  if (not g_globalVariableWatchers[service][variable]) then
    g_globalVariableWatchers[service][variable] = {}
  end
  
  if (lul_device ~= nil) then
    if (not g_deviceVariableWatchers[lul_device]) then
      g_deviceVariableWatchers[lul_device] = {}
    end
    if (not g_deviceVariableWatchers[lul_device][service]) then
      g_deviceVariableWatchers[lul_device][service] = {}
    end
    if (not g_deviceVariableWatchers[lul_device][service][variable]) then
      g_deviceVariableWatchers[lul_device][service][variable] = {}
    end
  end

end

local function addWatcher(service, lul_device, variable, function_name)
  initWatcherTables(service, lul_device, variable)

  if (lul_device == nil) then
    table.insert(g_globalVariableWatchers[service][variable], function_name)
  else
    table.insert(g_deviceVariableWatchers[lul_device][service][variable], function_name)
  end
end

local function getWatchers(service, lul_device, variable)
  initWatcherTables(service, lul_device, variable)

  local result = {}

  for k,v in pairs(g_deviceVariableWatchers[lul_device][service][variable]) do
    table.insert(result, v)
  end

  for k,v in pairs(g_globalVariableWatchers[service][variable]) do
    table.insert(result, v)
  end

  return result
end

local function getVariableTable(service, lul_device)
  if (not g_luupVariables[lul_device]) then
    g_luupVariables[lul_device] = {}
  end
  if (not g_luupVariables[lul_device][service]) then
    g_luupVariables[lul_device][service] = {}
  end
  return g_luupVariables[lul_device][service]
end

local function findFunction(functionTable, name)
  assert(type(name) == "string")
  for k, v in pairs(functionTable) do
    if (type(v) == "table") then
      local func = findFunction(v, name)
      if (func) then
        return func
      end
    elseif (type(v) == "function" and k == name) then
      return v
    end
  end
  return nil
end

--local function sleep(n)
--	os.execute("sleep " .. tonumber(n) / 1000)
--end

local function notifyWatchers(service, variable, variableValue, lul_device)
  local watchers = getWatchers(service, lul_device, variable)
  for k, v in pairs(watchers) do
    local func = findFunction(g_functions, v)
    local oldValue = getVariableTable(service, lul_device)[variable]
    func(lul_device, service, variable, oldValue, variableValue)
  end
end


-------------------------------
---- Luup Stub Functions ------
-------------------------------

function  log (message, luupLogLevel)
  if (not luupLogLevel) then
    luupLogLevel = 50
  end
  print(os.date("%m/%d/%Y %H:%M:%S") .. " [" .. luupLogLevel .. "] " ..message)
end

function  variable_set(service, name, value, lul_device)
  notifyWatchers(service, name, value, lul_device)
  log.debug("Setting [" .. lul_device .."][" .. service .."][" .. name .. "] = " .. value .. " (" .. type(value) .. ")")
  getVariableTable(service, lul_device)[name] = value
end


function  variable_get(service, name, lul_device)
  local value = getVariableTable(service, lul_device)[name]
  log.debug("Getting [" .. lul_device .."][" .. service .."][" .. name .. "] = " .. tostring(value) .. " (" .. type(value) .. ")")
  return(value)
end


function  call_delay(function_name, delay, data, thread)
  log.debug("luup.call_delay called, function_name = " .. function_name ..
    ", delay = " .. delay)
  g_callbackFunctions[function_name] = {}
  g_callbackFunctions[function_name].name = function_name
  g_callbackFunctions[function_name].executionTime = os.time() + delay
  g_callbackFunctions[function_name].data = data
end


function  sleep(sleepTime)
  log.debug ("Sleeping for " .. sleepTime .. " milliseconds")
  --sleep(sleepTime)
  socket.sleep(sleepTime / 1000)
end

function  attr_set(...)

end


function  task(...)

end

function  call_action(service, action, arguments, lul_device)
  log.debug("luup.call_action called, service = " , service , ", action = ", action,
    ", arguments = " ,arguments, ", lul_device = ", lul_device)
end

function  variable_watch(function_name, service, variable, lul_device)
  log.debug("luup.variable_watch called, ", "service = ", service, ", lul_device = ",lul_device,  ", variable = ", variable, ", functionName = ", functionName)
  addWatcher(service, lul_device, variable, function_name)
end

function  device_supports_service(service, lul_device)
  log.debug("luup.device_supports_service called: service = " , service , ", lul_device = ", lul_device)
  local vars = getVariableTable(service, lul_device)
  local supported = (#vars > 0)
  log.debug("luup.device_supports_service result: service = " , service , ", supported = ", supported)
  return supported
end

function  chdev_start(...)
  log.debug("luup.chdev.start called", arg)
end

function  chdev_sync(...)
  log.debug("luup.chdev.sync called", arg)

end

function  chdev_append(parentDeviceId, rootPtr,
  deviceId, description,
  deviceType,
  deviceFile, implementationFile, defaultParams, embedded)

  log.debug("luup.chdev.append called, ", parentDeviceId,  ", ",rootPtr, ", ",
    id,  ", ",description, ", ",
    deviceType, ", ",
    deviceFile,  ", ",implementationFile, ", ", defaultParams,  ", ",embedded)

  local newDeviceId = _createDevice(parentDeviceId, deviceId, description, deviceType, defaultParams)

  local function processParam(line)
    local service, variable, value =  string.match(line, "([^,]*),([^=]*)=(.*)")
    log.trace("service = ", service, ", variable = ", variable, ", value = ", value)
    variable_set(service,variable,value,newDeviceId)
  end

  string.gsub(defaultParams, "([^\n]+)", processParam)

end

-------------------------------------------
---- Test Harness Specific Functions ------
-------------------------------------------

function  _createDevice(parentDeviceId, deviceId, description, deviceType, defaultParams)

  log.trace("luup._createDevice called, ",parentDeviceId, ", ", deviceId,  ", ",description,  ", ",deviceType,  ", ",defaultParams)

  local deviceData = { ["description"] = description, ["id"] = deviceId, ["device_type"] = deviceType, ["device_num_parent"] = parentDeviceId }
  g_devices[g_nextDeviceId] = deviceData
  log.debug ("Added deviceId  = ", g_nextDeviceId)
  g_nextDeviceId = g_nextDeviceId + 1
  return g_nextDeviceId - 1
end

function  _addFunctions(functionsTable)
  table.insert(g_functions, functionsTable)
end

function  _callbackLoop()
  local nextFunc = nil

  repeat
    nextFunc = nil

    -- find the next function that needs execution
    for k,v in pairs(g_callbackFunctions) do
      if (not nextFunc or v.executionTime < nextFunc.executionTime) then
        nextFunc = v
      end
    end

    if (nextFunc) then
      g_callbackFunctions[nextFunc.name] = nil
      local now = os.time()
      if (nextFunc.executionTime > now) then
        log.debug ("Sleeping for " .. nextFunc.executionTime - now .. " seconds")
        sleep((nextFunc.executionTime - now) * 1000)
      end
      local func = findFunction(g_functions, nextFunc.name)
      if (func ~= nil) then
        log.debug ("Calling function " .. nextFunc.name)
        func (nextFunc.data)
      else
        log.debug ("Couldn't find function " .. nextFunc.name)
      end
    end
  until (not nextFunc)

  log.debug("luup._callbackLoop() complete")
end

function  _setLog(logModule)
  log = logModule
end


-- log.setConfig(LOG_CONFIG)

chdev = { start=chdev_start, sync=chdev_sync, append=chdev_append }

-- RETURN GLOBAL FUNCTIONS
return {
  variable_set=variable_set,
  variable_get=variable_get,
  call_delay=call_delay,
  sleep=sleep,
  attr_set=attr_set,
  task=task,
  call_action=call_action,
  variable_watch=variable_watch,
  device_supports_service=device_supports_service,
  log=log,
  devices=g_devices,
  chdev=chdev,
  _createDevice=_createDevice,
  _addFunctions=_addFunctions,
  _callbackLoop=_callbackLoop,
  _setLog=_setLog
}


