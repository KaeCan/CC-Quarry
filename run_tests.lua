---@diagnostic disable: undefined-global, lowercase-global
-- load modules from subdirectories
package.path = package.path .. ";/?/init.lua"

local framework = require("tests.framework")
local mocks = require("tests.mocks")

if not turtle then
    turtle = mocks.createTurtle()
end

framework.enableLogging()

framework.logPrint("Running Quarry Test Suite")
framework.logPrint("=======================")

require("tests.test_utils")
require("tests.test_item_filter")
require("tests.test_fuel")
require("tests.test_inventory")
require("tests.test_tracker")

framework.printStats()

if framework.saveLog("test.log") then
    framework.logPrint("Test log saved to test.log")
end
