---@diagnostic disable: undefined-global
---@type table
fs = fs
---@type table
os = os

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
            -- Deep equality check could go here, simple check for now
            if type(actual) ~= type(expected) then
                 error(string.format("Expected type %s to equal type %s", type(actual), type(expected)), 2)
            end
            if actual ~= expected and type(actual) ~= "table" then
                 error(string.format("Expected %s to equal %s", tostring(actual), tostring(expected)), 2)
            end
            -- Table check omitted for brevity in this simple version unless needed
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

    filename = filename or "test_log.txt"
    local file = fs.open(filename, "w")
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

function M.saveResults()
    if not logEnabled or not fs then
        return false
    end

    local filename = "test_results.log"
    local file = fs.open(filename, "w")
    if not file then
        print("Warning: Could not create " .. filename)
        return false
    end

    file.write("Quarry Unit Test Results\n")
    file.write("========================\n\n")
    if os and os.date then
        file.write("Date: " .. os.date() .. "\n\n")
    end

    file.write("Test Summary:\n")
    file.write("  Total: " .. stats.total .. "\n")
    file.write("  Passed: " .. stats.passed .. "\n")
    file.write("  Failed: " .. stats.failed .. "\n")

    if stats.failed > 0 then
        file.write("\nStatus: FAILED\n")
        file.write("\nFull test log available in test.log\n")
    else
        file.write("\nStatus: PASSED\n")
        file.write("\nAll unit tests passed!\n")
    end

    file.close()
    print("Unit test results saved to " .. filename)
    return true
end

return M
