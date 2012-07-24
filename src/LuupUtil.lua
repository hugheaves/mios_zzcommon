-- MiOS Utility Functions
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
local luup = luup
local string = string
local log = g_log

-- CONSTANTS
local T_NUMBER = "T_NUMBER"
local T_BOOLEAN = "T_BOOLEAN"
local T_STRING = "T_STRING"

-- GLOBALS

local function luupLog(message, level)
	local luupLogLevel 
	if (level <= log.LOG_LEVEL_ERROR) then
		luupLogLevel = 1
	elseif (level <= log.LOG_LEVEL_INFO) then
		luupLogLevel = 2
	else
		luupLogLevel = 50
	end
	luup.log(message, luupLogLevel)
end

-- initalize a Luup variable to a value if it's not already set
local function initVariableIfNotSet(serviceId, variableName, initValue, lul_device)
	local value = luup.variable_get(serviceId, variableName, lul_device)
	log.debug ("initVariableIfNotSet: lul_device [",lul_device,"] serviceId [",serviceId,"] Variable Name [",variableName,
	"] Lua Type [", type(value), "] Value [", value, "]")
	if (value == nil or value == "") then
		luup.variable_set(serviceId, variableName, initValue, lul_device)
	end
end

--- return a Luup variable with the added capability to convert to a the
-- appropriate Lua type.
-- The Luup API _should_ do this automatically as the variables are
-- all declared with types, but it doesn't. Grrrr.....
local function getLuupVariable(serviceId, variableName, lul_device, varType) 
	if (type(lul_device) == "string") then
--		log.debug ("Converting lul_device to number for device ", lul_device)
		lul_device = tonumber(lul_device)
	end
	
	local value = luup.variable_get(serviceId, variableName, lul_device)
	local returnValue = nil
	if (not value) then
		returnValue = nil
	elseif (varType == T_BOOLEAN) then
		returnValue = (value == "1")
	elseif (varType == T_NUMBER) then
		returnValue = tonumber(value)
	elseif (varType == T_STRING) then
		returnValue = tostring(value)
	else
		error ("Invalid varType passed to getLuupVariable, serviceId = " .. serviceId ..
			", variableName = " .. variableName .. ", lul_device = " .. lul_device ..
			", varType = " .. tostring(varType) )
		return nil
	end
	
	log.debug ("getLuupVariable: lul_device [",lul_device,"] serviceId [",serviceId,"] Variable Name [",variableName,
	"] Lua Type [", type(value), "] Value [", value, "] varType [", varType, "] returnValue [", returnValue, "]")
	
	return returnValue
end

local function setLuupVariable(serviceId, variableName, value, lul_device, varType) 
	log.debug ("setLuupVariable: lul_device [",lul_device,"] serviceId [",serviceId,"] Variable Name [",variableName,
	"] Lua Type [", type(value), "] Value [", value, "]", "] varType [", varType, "]")
	
	if (type(lul_device) == "string") then
--		log.debug ("Converting lul_device to number for device ", lul_device)
		lul_device = tonumber(lul_device)
	end
	
	if (varType == T_BOOLEAN and value ~= nil) then
		if (value) then
			luup.variable_set(serviceId, variableName, "1", lul_device)
		else
			luup.variable_set(serviceId, variableName, "0", lul_device)
		end
	else 
		luup.variable_set(serviceId, variableName, value, lul_device)
	end
end

-- initialize the logging system
local function initLogging(logPrefix, logFilter, logLevelSID, logLevelVar, logLevelDevice)
	log.setPrefix(logPrefix)
	log.setLogFunction(luupLog)
	log.addFilter(logFilter)
	initVariableIfNotSet(logLevelSID, logLevelVar, log.LOG_LEVEL_INFO, logLevelDevice)
	log.setLevel(getLuupVariable(logLevelSID, logLevelVar, logLevelDevice, T_NUMBER))
end

-- RETURN GLOBAL FUNCTION TABLE
return {
	initVariableIfNotSet = initVariableIfNotSet,
	getLuupVariable = getLuupVariable,
	setLuupVariable = setLuupVariable,
	luupLog = luupLog,
	initLogging = initLogging,
	T_NUMBER = T_NUMBER,
	T_BOOLEAN = T_BOOLEAN,
	T_STRING = T_STRING
}

