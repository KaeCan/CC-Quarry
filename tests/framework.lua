---@diagnostic disable: undefined-global
---@type table
fs = fs
---@type table
os = os
---@type table
shell = shell

local utils = require("modules.utils")
local M = {}

local red = colors.red
local green = colors.lime
local white = colors.white
local gray = colors.gray

local logBuffer = {}
local logEnabled = false

local function logText(text)
    if logEnabled then
        table.insert(logBuffer, text)
    end
    print(text)
end

local function printColor(text, color)
    if term.isColor() then
        term.setTextColor(color)
    end
    logText(text)
    if term.isColor() then
        term.setTextColor(white)
    end
end

local stats = {
    passed = 0,
    failed = 0,
    total = 0
}

function M.describe(name, callback)
    logText("")
    logText("Suite: " .. name)
    logText("")
    callback()
end

function M.it(name, callback)
    stats.total = stats.total + 1
    local status, err = pcall(callback)
    if status then
        stats.passed = stats.passed + 1
        printColor("  [PASS] ", green)
        logText(name)
    else
        stats.failed = stats.failed + 1
        printColor("  [FAIL] ", red)
        logText(name)
        local errorMsg = "    Error: " .. tostring(err)
        printColor(errorMsg, red)
        logText("")
    end
end

function M.expect(actual)
    return {
        toBe = function(expected)
            if actual ~= expected then
                error(string.format("Expected %s to be %s", tostring(actual), tostring(expected)), 2)
            end
        end,
        notToBe = function(expected)
            if actual == expected then
                error(string.format("Expected %s not to be %s", tostring(actual), tostring(expected)), 2)
            end
        end,
        toBeTruthy = function()
            if not actual then
                error(string.format("Expected %s to be truthy", tostring(actual)), 2)
            end
        end,
        toBeFalsy = function()
            if actual then
                error(string.format("Expected %s to be falsy", tostring(actual)), 2)
            end
        end,
        toEqual = function(expected)
            if type(actual) ~= type(expected) then
                 error(string.format("Expected type %s to equal type %s", type(actual), type(expected)), 2)
            end
            if actual ~= expected and type(actual) ~= "table" then
                 error(string.format("Expected %s to equal %s", tostring(actual), tostring(expected)), 2)
            end
        end,
        toBeGreaterThan = function(expected)
            if type(actual) ~= "number" or type(expected) ~= "number" then
                error(string.format("toBeGreaterThan requires numbers, got %s and %s", type(actual), type(expected)), 2)
            end
            if actual <= expected then
                error(string.format("Expected %s to be greater than %s", tostring(actual), tostring(expected)), 2)
            end
        end,
        toBeLessThan = function(expected)
            if type(actual) ~= "number" or type(expected) ~= "number" then
                error(string.format("toBeLessThan requires numbers, got %s and %s", type(actual), type(expected)), 2)
            end
            if actual >= expected then
                error(string.format("Expected %s to be less than %s", tostring(actual), tostring(expected)), 2)
            end
        end,
        toBeLessThanOrEqual = function(expected)
            if type(actual) ~= "number" or type(expected) ~= "number" then
                error(string.format("toBeLessThanOrEqual requires numbers, got %s and %s", type(actual), type(expected)), 2)
            end
            if actual > expected then
                error(string.format("Expected %s to be less than or equal to %s", tostring(actual), tostring(expected)), 2)
            end
        end,
        toContain = function(expected)
            if type(actual) ~= "string" then
                error(string.format("toContain requires string, got %s", type(actual)), 2)
            end
            if type(expected) ~= "string" then
                error(string.format("toContain expected value must be string, got %s", type(expected)), 2)
            end
            if not string.find(actual, expected, 1, true) then
                error(string.format("Expected '%s' to contain '%s'", actual, expected), 2)
            end
        end
    }
end

function M.printStats()
    logText("")
    local separator = string.rep("-", 20)
    logText(separator)

    local totalText = "Total: " .. stats.total
    printColor(totalText, white)

    if term.isColor() then
        term.setTextColor(white)
    end
    logText(" | ")

    local passedText = "Passed: " .. stats.passed
    printColor(passedText, green)

    if term.isColor() then
        term.setTextColor(white)
    end
    logText(" | ")

    local failedText = "Failed: " .. stats.failed
    printColor(failedText, stats.failed > 0 and red or green)

    logText("")
end

function M.enableLogging()
    logEnabled = true
    logBuffer = {}
end

function M.logPrint(...)
    local args = {...}
    local text = ""
    for i, arg in ipairs(args) do
        if i > 1 then
            text = text .. "\t"
        end
        text = text .. tostring(arg)
    end
    logText(text)
end

function M.saveLog(filename)
    if not logEnabled or not fs then
        return false
    end

    filename = filename or "test.log"
    local logPath = utils.getScriptPath(filename)

    local file = fs.open(logPath, "w")
    if not file then
        return false
    end

    file.write("Quarry Test Suite Log\n")
    file.write("====================\n")
    if os and os.date then
        file.write("Date: " .. os.date() .. "\n")
    end
    file.write("\n")

    for _, line in ipairs(logBuffer) do
        file.write(line .. "\n")
    end

    file.write("\n")
    file.write("Summary:\n")
    file.write("  Total: " .. stats.total .. "\n")
    file.write("  Passed: " .. stats.passed .. "\n")
    file.write("  Failed: " .. stats.failed .. "\n")

    file.close()
    return true
end

return M
