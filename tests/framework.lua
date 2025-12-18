local M = {}

local red = colors.red
local green = colors.lime
local white = colors.white
local gray = colors.gray

local function printColor(text, color)
    if term.isColor() then
        term.setTextColor(color)
    end
    write(text)
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
    print()
    printColor("Suite: " .. name, white)
    print()
    callback()
end

function M.it(name, callback)
    stats.total = stats.total + 1
    local status, err = pcall(callback)
    if status then
        stats.passed = stats.passed + 1
        printColor("  [PASS] ", green)
        print(name)
    else
        stats.failed = stats.failed + 1
        printColor("  [FAIL] ", red)
        print(name)
        printColor("    Error: " .. tostring(err), red)
        print()
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
    print()
    print(string.rep("-", 20))
    printColor("Total: " .. stats.total, white)
    print(" | ", white)
    printColor("Passed: " .. stats.passed, green)
    print(" | ", white)
    printColor("Failed: " .. stats.failed, stats.failed > 0 and red or green)
    print()
end

return M
