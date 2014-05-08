-- Generic Lua Logging Facility
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

--
-- This logging module provides some higher level
-- functionality on top of Luup logging.
--

-- IMPORT GLOBALS
local luadebug = debug
local string = string

--
-- CONSTANTS
--

-- special logging level using in logging configuration table
local LOG_LEVEL_DEFAULT = -1

-- Module specific logging levels. Call the  "setLevel" function
-- with one of these
local LOG_LEVEL_ERROR = 10
local LOG_LEVEL_INFO = 20
local LOG_LEVEL_DEBUG = 30
local LOG_LEVEL_TRACE = 40

local LOG_LEVELS = {
  [LOG_LEVEL_ERROR] = "ERROR",
  [LOG_LEVEL_INFO] = "INFO",
  [LOG_LEVEL_DEBUG] = "DEBUG",
  [LOG_LEVEL_TRACE] = "TRACE"
}

local DATE_FORMAT = "%m/%d/%y %H:%M:%S"

local function defaultLogFunction(message, level)
  print (os.date(DATE_FORMAT, os.time()) .. " " .. message)
end

local g_currentLogLevel = LOG_LEVEL_INFO
local g_logConfig = {}
local g_logPrefix = ""
local g_logFunc = defaultLogFunction

-- silly function that returns value, or "nil" if value is nil
local function nilSafe(value)
  if (value) then
    return value
  else
    return "nil"
  end
end

-- lookup a key in a table by its value
local function findKeyByValue(table, value)
  for k,v in pairs(table) do
    if (v == value) then
      return k
    end
  end

  return nil;
end


-- function adapted from http://www.luafaq.org/
local function deepToString(o)
  if (o == nil) then
    return "nil"
  elseif type(o) == 'string' then
    return o
  elseif type(o) == 'number' then
    return tostring(o)
  elseif type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then
        k = '"'..k..'"'
      end
      if type(v) == 'string' then
        v = '"' .. v .. '"'
      else
        v = deepToString(v)
      end
      s = s .. '['..k..'] = ' .. v .. ','
    end
    return s .. '} '
  else
    return '"' .. tostring(o) .. '"'
  end
end

--- Determine the currently configured logging level
-- for the given fileName and functionName
local function getConfiguredLogLevel(fileName, functionName)
  local level = nil
 
  if (g_logConfig.version and g_logConfig.version == 1) then
    local fileConfig = g_logConfig.files[fileName]
    if (fileConfig ~= nil) then
      if (fileConfig.functions[functionName]) then
        level = fileConfig.functions[functionName]
      else
        level = fileConfig.level
      end
    end
  end

  if (level ~= nil and level ~= LOG_LEVEL_DEFAULT) then
    return level
  end

  return g_currentLogLevel
end

local function getCallLocation(debugInfo)
  if (not debugInfo) then
    return nil, nil, nil, nil
  end

  local fileName, functionName, line

  if (debugInfo.what == "main") then
    functionName = "MAIN"
  elseif (debugInfo.name) then
    functionName = debugInfo.name
  else
    functionName = "unknownFunction"
  end

  if (debugInfo.short_src == "[C]") then
    fileName = "C_Code"
    functionName = "C_Function"
  else
    -- return filename part of path
    -- Ex: @/etc/cmh-ludl/L_Zabbix_util.lua
    -- return: L_Zabbix_util.lua
    fileName = debugInfo.source:match("@.*/(.*)")
  end

  if (fileName == nil) then
    fileName = "unknown"
  end

  if (debugInfo.currentline and debugInfo.currentline ~= -1) then
    line = debugInfo.currentline
  else
    line = "unknownLine"
  end

  return functionName, fileName, line, table.concat({"(", functionName, "@", fileName , ":" , line , ")"})
end

--- internal function builds a message
-- and logs at the given level using g_logFunc
local function doLog(level, stackDepth, ...)
  local args = {...}

  local callerInfo = luadebug.getinfo(stackDepth, "nlS")
  -- print ("doLog debugInfo" .. deepToString(debugInfo))

  local functionName, fileName, line, locationString = getCallLocation(callerInfo)

  local configuredLevel = getConfiguredLogLevel(fileName, functionName)

  -- print ("configuredLevel = ", configuredLevel)

  if (level <= configuredLevel) then
    local message = {g_logPrefix , " " , LOG_LEVELS[level] , locationString , ") - "}

    for i = 1, #args, 1 do
      table.insert(message, deepToString(args[i]))
    end

    g_logFunc(table.concat(message), level)
  end
end

local function logInternal(logLevel, ...)
  local STACK_DEPTH = 4
  if (g_currentLogLevel >= logLevel) then
    doLog (logLevel, STACK_DEPTH, ...)
  end
end

local function log(logLevel, ...)
  logInternal(logLevel)
end

-- log an error message
local function error(...)
  logInternal (LOG_LEVEL_ERROR, ...)
end

-- log an informational message
local function info(...)
  logInternal (LOG_LEVEL_INFO, ...)
end

-- log a debugging message
local function debug(...)
  logInternal (LOG_LEVEL_DEBUG, ...)
end

-- log a trace message
local function trace(...)
  logInternal (LOG_LEVEL_TRACE, ...)
end

local function logValuesInternal(logLevel, message, ...)
  if (g_currentLogLevel >= logLevel) then
    local args = {...}
    local logMessage = { message, ": " }
    local i
    for i = 1,#args,2 do
      table.insert(logMessage, args[i])
      table.insert(logMessage, " = ")
      table.insert(logMessage, deepToString(args[i+1]))
      table.insert(logMessage, " (")
      table.insert(logMessage, type(args[i+1]))
      table.insert(logMessage, ")")
      if (i < #args - 1) then
        table.insert(logMessage, ", ")
      end
    end
    local STACK_DEPTH = 4
    doLog (logLevel, STACK_DEPTH,table.concat(logMessage))
  end
end

local function logValues(logLevel, message, ...)
  logValuesInternal(logLevel, message, ...)
end

-- log a debugging message
local function errorValues(message, ...)
  logValuesInternal(LOG_LEVEL_DEBUG, message, ...)
end

-- log a debugging message
local function infoValues(message, ...)
  logValuesInternal(LOG_LEVEL_INFO, message, ...)
end

-- log a debugging message
local function debugValues(message, ...)
  logValuesInternal(LOG_LEVEL_DEBUG, message, ...)
end

-- log a debugging message
local function traceValues(message, ...)
  logValues(LOG_LEVEL_TRACE, message, ...)
end


--- This function is registered with Lua debug.sethook()
-- when the logLevel is set to TRACE.
-- It provides logging of function exit and entry to assist with debugging
local function logHook(hookType)
  -- print ("LOG HOOK START ", hookType)

  for i = 1, 1000, 1 do
    local calledFunctionInfo = luadebug.getinfo(i, "nlS")
    if (not calledFunctionInfo) then
      break
    end
    --print ("STACK[" .. i .. "]\n" , deepToString(calledFunctionInfo), "\n")
  end

  local FUNCTION_STACK_DEPTH = 2

  -- retrieve info fields: source, short_src, linedefined, lastlinedefined, and what
  local calledFunctionInfo = luadebug.getinfo(FUNCTION_STACK_DEPTH, "S")
  --print ("CALLED FUNCTION INFO:\n" , deepToString(calledFunctionInfo), "\n")

  -- only log the call stack if we're in Lua code
  if (not calledFunctionInfo or (calledFunctionInfo.what ~= "Lua" and calledFunctionInfo.what ~= "main")) then
    --print ("NOT A LUA FUNCTION")
    return
  end

  local thisFunctionInfo = luadebug.getinfo(1, "S")
  --  print ("LOG HOOK THIS FUNCTION DEBUG INFO ", deepToString(thisFunctionInfo), "\n")
  -- don't write log function calls for functions in this file
  if (thisFunctionInfo.short_src == calledFunctionInfo.short_src) then
    --  print ("NOT LOGGING SELF")
    return
  end

  local message = {}

  if (hookType == "call") then
    table.insert(message, "ENTRY\nCalled From:\n")
  elseif (hookType == "return") then
    table.insert(message, "EXIT\nReturning To:\n")
  else
    print ("NOT A CALL / RETURN HOOK")
    -- should never get here
    return
  end

  for stackLevel = FUNCTION_STACK_DEPTH + 1, 1000, 1 do
    local stackInfo = luadebug.getinfo(stackLevel, "nlS")
    if (not stackInfo) then
      break
    end
    local functionName, fileName, line, locationString = getCallLocation(stackInfo)
    table.insert(message,locationString)
    table.insert(message,"\n")
    --   print ("LOG HOOK CALLER DEBUG INFO ", deepToString(debugInfo), "\n")
  end

  --print ("\n" .. table.concat(message) .. "\n")
  doLog(LOG_LEVEL_TRACE, FUNCTION_STACK_DEPTH + 1, table.concat(message))
  --print ("LOG HOOK RETURNING")
end

local function enableDebugHook()
  luadebug.sethook (logHook, "cr")
end

local function disableDebugHook()
  luadebug.sethook ()
end

--- set the log level and install or remove the debug hook depending on the new level
local function setLevel(newLogLevel)
  g_currentLogLevel = newLogLevel
end

local function setPrefix(logPrefix)
  g_logPrefix = logPrefix
end

local function setLogFunction(logFunction)
  g_logFunc = logFunction
end

local function setConfig(logConfig)
  if (logConfig ~= nil) then
    g_logConfig = logConfig
  end
end

local function getConfig()
  return g_logConfig
end

-- RETURN GLOBAL FUNCTION TABLE
return {
  log = log,
  trace = trace,
  debug = debug,
  info = info,
  error = error,
  logValues = logValues,
  traceValues = traceValues,
  debugValues = debugValues,
  infoValues = infoValues,
  errorValues = errorValues,
  setPrefix = setPrefix,
  setLevel = setLevel,
  setConfig = setConfig,
  getConfig = getConfig,
  setLogFunction = setLogFunction,
  enableDebugHook = enableDebugHook,
  disableDebugHook = disableDebugHook,
  LOG_LEVEL_ERROR = LOG_LEVEL_ERROR,
  LOG_LEVEL_INFO = LOG_LEVEL_INFO,
  LOG_LEVEL_DEBUG = LOG_LEVEL_DEBUG,
  LOG_LEVEL_TRACE = LOG_LEVEL_TRACE
}
