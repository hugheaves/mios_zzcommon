package.path = package.path .. ";../src/?.lua"

local dkjson = require ("dkjson")
local log = require ("LogUtil")

local testConfig = {
		["version"] = 1,
		["files"] = {
			["./*LogUtil.lua$"] = {
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
	complicatedFunction()
end

print ("==================================")
log.setPrefix ("TestingLog")
writeSomeLogMessages()

print ("==================================")
log.setLevel(log.LOG_LEVEL_DEBUG)
writeSomeLogMessages()

print ("==================================")
log.enableDebugHook()
log.setLevel(log.LOG_LEVEL_TRACE)
writeSomeLogMessages()

print ("==================================")
log.setConfig(testConfig)
writeSomeLogMessages()
