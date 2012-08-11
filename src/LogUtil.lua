-- Generic Lua Logging Facility
--
-- Copyright (C) 2012  Hugh Eaves
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

local g_logLevel = LOG_LEVEL_INFO
local g_logConfig = {}
local g_logPrefix = ""
local g_logFunc = print

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

local function getMinLogLevel(fileName, functionName, level)
	local matched = false

	if (g_logConfig.version and g_logConfig.version == 1) then
		for filePattern, data in pairs(g_logConfig.files) do
			matched = fileName:find(filePattern)
			if (matched) then
				if (data.functions[functionName]) then
					level = data.functions[functionName]
				else
					level = data.level
				end
				break
			end
		end
	end
	
	return level
end

--- internal function builds a message
-- and logs at the given level using g_logFunc
local function doLog(level, callerLevel, separator, arg)
	local functionName = "unknown"
	local fileName = "unknown"
	local line = "unknown"

	local info = luadebug.getinfo(callerLevel, "nlS")
	if (info and info.name) then
		functionName = info.name
	end
	if (info and info.short_src) then
		fileName = info.short_src
	end
	if (info and info.currentline) then
		line = info.currentline
	end


	if (level <= getMinLogLevel(fileName, functionName, g_logLevel)) then
		local message = {g_logPrefix , " " , LOG_LEVELS[level] , " (", functionName , ":" , line , ")", separator}

		for i = 1, arg.n, 1 do
			table.insert(message, deepToString(arg[i]))
		end

		g_logFunc(table.concat(message), level)
	end
end

-- log an error message
local function error(...)
	doLog (LOG_LEVEL_ERROR, 3, " - ", arg)
end

-- log an informational message
local function info(...)
	if (g_logLevel >= LOG_LEVEL_INFO) then
		doLog (LOG_LEVEL_INFO, 3, " - ",arg)
	end
end

-- log a debugging message
local function debug(...)
	if (g_logLevel >= LOG_LEVEL_DEBUG) then
		doLog (LOG_LEVEL_DEBUG, 3, " - ",arg)
	end
end

-- log a trace message
local function trace(...)
	if (g_logLevel >= LOG_LEVEL_TRACE) then
		doLog (LOG_LEVEL_TRACE, 3, " - ",arg)
	end
end

--- This function is registered with Lua debug.sethook()
-- when the logLevel is setup to TRACE.
-- It provides logging of function exit and entry to assist with debugging
local function logHook(hookType)

	local message = ""
	local callerLevel = 2

	local info = luadebug.getinfo(callerLevel, "S")
		if (not info or info.what ~= "Lua" or not info.source or info.source:len() < 1 or info.source:byte(1) ~= 64) then
		return
	end
	
	if (hookType == "call") then
		message = "<----- Called From: "
	elseif (hookType == "return") then
		message = "-----> Exiting To: "
	end

	local seperator = ""
	repeat
		callerLevel = callerLevel + 1
		info = luadebug.getinfo(callerLevel, "nlS")
		if (info) then
			local src = info.short_src or "nil"
			local name = info.name and info.name or src
			local line = info.currentline and info.currentline or "unknown"
			message = message .. seperator .. "(" .. name .. ":" .. line .. ")"
			if (hookType == "call") then
				seperator = " <- "
			else
				seperator = " -> "
			end
		end
	until (not info)

	doLog(LOG_LEVEL_TRACE, 3, " ", { ["n"] = 1, [1] = message })
end

local function enableDebugHook()
	luadebug.sethook (logHook, "cr")
end

local function disableDebugHook()
	luadebug.sethook ()
end

--- set the log level and install or remove the debug hook depending on the new level
local function setLevel(newLogLevel)
	g_logLevel = newLogLevel
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
	trace = trace,
	debug = debug,
	info = info,
	error = error,
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
