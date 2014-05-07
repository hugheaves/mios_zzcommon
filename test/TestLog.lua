package.path = package.path .. ";../src/?.lua"

local dkjson = require ("dkjson")
local log = require ("LogUtil")

local testConfig = {
		["version"] = 1,
		["files"] = {
			["./*TestLog.lua$"] = {
				["level"] = log.LOG_LEVEL_INFO,
				["functions"] = {
					["complicatedFunction"] = log.LOG_LEVEL_TRACE,
				}
			}
		}
	}

local function reallyComplicatedFunction()
	log.trace ("A A A A")
	log.debug ("B B B B")
	log.info ("C C C C")
	log.error ("D D D D")
end

local function complicatedFunction()
	log.trace ("1111")
	log.debug ("222")
	log.info ("3333")
	log.error ("4444")
end

local function writeSomeLogMessages()
	reallyComplicatedFunction()
	log.trace ("yada yada yada")
	log.debug ("dooby dooby doo")
	log.info ("banana bobana")
	log.error ("here we go")
	log.debugValues("message", "a", 1, "b", 2, "c", "three")
	complicatedFunction()
end

print ("==================================")
print ("USING LOGGING DEFAULTS")
print ("==================================")
log.setPrefix ("TestLog")
writeSomeLogMessages()

print ("==================================")
print ("SETTING DEBUG LEVEL")
print ("==================================")
log.setLevel(log.LOG_LEVEL_DEBUG)
writeSomeLogMessages()

print ("==================================")
print ("ENABLING DEBUG HOOK")
print ("==================================")
log.setLevel(log.LOG_LEVEL_TRACE)
log.enableDebugHook()
writeSomeLogMessages()


print ("==================================")
print ("SETTING CONFIG")
print ("==================================")
log.setConfig(testConfig)
writeSomeLogMessages()
