-- MiOS Plugin Test Harness
--
-- Copyright (C) 2014  Hugh Eaves
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

-- IMPORT REQUIRED MODULES
socket = require("socket")
_log = require("L_" .. g_pluginName .. "_log")

-----------------------------
---- Globals ----------------
-----------------------------

g_luupVariables = {}

g_deviceVariableWatchers = {}

g_globalVariableWatchers = {}

g_callbackFunctions = {}

g_functions = {}

g_nextDeviceId = 1000

g_devices = {}

------------------------------------------
---- Support / Internal Functions --------
------------------------------------------

function _initWatcherTables(service, lul_device, variable)
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

function _addWatcher(service, lul_device, variable, function_name)
  _initWatcherTables(service, lul_device, variable)

  if (lul_device == nil) then
    table.insert(g_globalVariableWatchers[service][variable], function_name)
  else
    table.insert(g_deviceVariableWatchers[lul_device][service][variable], function_name)
  end
end

function _getWatchers(service, lul_device, variable)
  _initWatcherTables(service, lul_device, variable)

  local result = {}

  for k,v in pairs(g_deviceVariableWatchers[lul_device][service][variable]) do
    table.insert(result, v)
  end

  for k,v in pairs(g_globalVariableWatchers[service][variable]) do
    table.insert(result, v)
  end

  return result
end

function  _initVariableTable(service, lul_device)
  if (not g_luupVariables[lul_device]) then
    g_luupVariables[lul_device] = {}
  end
  if (not g_luupVariables[lul_device][service]) then
    g_luupVariables[lul_device][service] = {}
  end
  return g_luupVariables[lul_device][service]
end

function _getVariableTable(service, lul_device)
  _initVariableTable(service, lul_device)
  return g_luupVariables[lul_device][service]
end

function _getVariable(service, variable, lul_device)
  return _getVariableTable(service, lul_device)[variable]
end

function _setVariable(service, variable, value, lul_device)
  local table = _getVariableTable(service, lul_device);
  table[variable] = value
end

function _findFunction(functionTable, name)
  assert(type(name) == "string")
  for k, v in pairs(functionTable) do
    if (type(v) == "table") then
      local func = _findFunction(v, name)
      if (func) then
        return func
      end
    elseif (type(v) == "function" and k == name) then
      return v
    end
  end
  return nil
end

local function _notifyWatchers(service, variable, value, lul_device, oldValue)
  _log.debugValues("Notifying Watchers", "service", service, "variable", variable, "value", value, "lul_device", lul_device)
  local watchers = _getWatchers(service, lul_device, variable)
  _log.debug("Current Watchers List: ", watchers)
  for k, v in pairs(watchers) do
    _log.debug("Calling function: ", v)
    local func = _findFunction(g_functions, v)
    func(lul_device, service, variable, oldValue, value)
  end
end

function  _createDevice(device_num_parent, deviceId, description, deviceType, defaultParams)

  _log.trace("luup._createDevice called, ",device_num_parent, ", ", deviceId,  ", ",description,  ", ",deviceType,  ", ",defaultParams)

  local deviceData = { ["description"] = description, ["id"] = deviceId, ["device_type"] = deviceType, ["device_num_parent"] = device_num_parent }
  g_devices[g_nextDeviceId] = deviceData
  _log.debug ("Added deviceId  = ", g_nextDeviceId)
  g_nextDeviceId = g_nextDeviceId + 1
  return g_nextDeviceId - 1
end

function  _addFunctions(functionsTable)
  log.debug("Adding functions: ", functionsTable)
  table.insert(g_functions, functionsTable)
end

function  _callbackLoop()
  local nextFunc = nil
  local index = nil

  repeat
    index = nil
    nextFunc = nil

    -- find the next function that needs execution
    for k,v in pairs(g_callbackFunctions) do
      if (not nextFunc or v.executionTime < nextFunc.executionTime) then
        index = k
        nextFunc = v
      end
    end

    if (nextFunc) then
      table.remove(g_callbackFunctions, index)
      local now = os.time()
      if (nextFunc.executionTime > now) then
        _log.debug ("Sleeping for " .. nextFunc.executionTime - now .. " seconds")
        sleep((nextFunc.executionTime - now) * 1000)
      end
      local func = _findFunction(g_functions, nextFunc.name)
      if (func ~= nil) then
        _log.debug ("Calling function " .. nextFunc.name)
        func (nextFunc.data)
      else
        _log.error ("Couldn't find function " .. nextFunc.name)
      end
    end
  until (not nextFunc)

  _log.debug("luup._callbackLoop() complete")
end

function  _setLog(logModule)
  log = logModule
end

function _findChild(parent_device, child_id)
  local children = {}
  for k, v in pairs(g_devices) do
    if (v.device_num_parent == parent_device and v.id == child_id) then
      return k
    end
  end
  return nil
end

function _dumpState()
  _log.debug("g_luupVariables", g_luupVariables)
  _log.debug("g_deviceVariableWatchers", g_deviceVariableWatchers)
  _log.debug("g_globalVariableWatchers", g_globalVariableWatchers)
  _log.debug("g_callbackFunctions", g_callbackFunctions)
  _log.debug("g_functions", g_functions)
  _log.debug("g_nextDeviceId", g_nextDeviceId)
  _log.debug("g_devices", g_devices)
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

function  variable_set(service, variable, value, lul_device)
  local oldValue = _getVariable(service, variable, lul_device)
  _setVariable(service, variable, value, lul_device)

  _notifyWatchers(service, variable, value, lul_device, oldValue)
  _log.debug("Setting [" .. lul_device .."][" .. service .."][" .. variable .. "] = " .. value .. " (" .. type(value) .. ")")
end


function  variable_get(service, variable, lul_device)
  local value = _getVariable(service, variable, lul_device)
  _log.trace("Getting [" .. lul_device .."][" .. service .."][" .. variable .. "] = " .. tostring(value) .. " (" .. type(value) .. ")")
  return(value)
end


function  call_delay(function_name, delay, data, thread)
  _log.debug("luup.call_delay called, function_name = " .. function_name ..
    ", delay = " .. delay)
  local callbackInfo = {}
  callbackInfo.name = function_name
  callbackInfo.executionTime = os.time() + delay
  callbackInfo.data = data
  table.insert(g_callbackFunctions, callbackInfo)
end


function  sleep(sleepTime)
  _log.debug ("Sleeping for " .. sleepTime .. " milliseconds")
  socket.sleep(sleepTime / 1000)
end

function  attr_set(...)

end


function  task(...)

end

function  call_action(service, action, arguments, lul_device)
  _log.debug("luup.call_action called, service = " , service , ", action = ", action,
    ", arguments = " ,arguments, ", lul_device = ", lul_device)
end

function  variable_watch(function_name, service, variable, lul_device)
  _log.debugValues("Registering Watcher", "service", service, "lul_device",lul_device,  "variable", variable, "function_name", function_name)
  _addWatcher(service, lul_device, variable, function_name)
end

function  device_supports_service(service, lul_device)
  local vars = _getVariableTable(service, lul_device)
  local supported = next(vars) ~= nil
  _log.debug("Device supported", "lul_device", lul_device, "service", service, "supported", supported)
  return supported
end

chdev = {}

function  chdev.start(...)
  _log.debug("luup.chdev.start called", ...)
end

function  chdev.sync(...)
  _log.debug("luup.chdev.sync called", ...)

end

function  chdev.append(parent_device, rootPtr,
  child_id, description,
  deviceType,
  deviceFile, implementationFile, defaultParams, embedded)

  _log.debug("luup.chdev.append called, ", parent_device,  ", ",rootPtr, ", ",
    child_id,  ", ",description, ", ",
    deviceType, ", ",
    deviceFile,  ", ",implementationFile, ", ", defaultParams,  ", ",embedded)

  local childDevice =  _findChild(parent_device, child_id)

  if (not childDevice) then
    childDevice = _createDevice(parent_device, child_id, description, deviceType, defaultParams)
    _log.debug("Created new child device: ", childDevice)
  else
    _log.debug("Found existing child device: ", childDevice)
  end

  local function processParam(line)
    local service, variable, value =  string.match(line, "([^,]*),([^=]*)=(.*)")
    _log.debug("service = ", service, ", variable = ", variable, ", value = ", value)
    if (not variable_get(service, variable, childDevice)) then
      variable_set(service,variable,value,childDevice)
    end
  end

  string.gsub(defaultParams, "([^\n]+)", processParam)

end

-------------------------------------------
---- Test Harness Specific Functions ------
-------------------------------------------

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
  _findChild=_findChild,
  _setLog=_setLog,
  _dumpState=_dumpState
}


