---@diagnostic disable: undefined-global, lowercase-global
-- load modules from subdirectories
package.path = package.path .. ";/?/init.lua"

-- Mock ComputerCraft APIs for local testing
local mocks = require("tests.mocks")
if not turtle then
    turtle = mocks.createTurtle()
end

if not colors then
    colors = {
        white = 0,
        orange = 1,
        magenta = 2,
        lightBlue = 3,
        yellow = 4,
        lime = 5,
        pink = 6,
        gray = 7,
        lightGray = 8,
        cyan = 9,
        purple = 10,
        blue = 11,
        brown = 12,
        green = 13,
        red = 14,
        black = 15
    }
end

if not term then
    term = {
        isColor = function() return false end,
        setTextColor = function() end,
        setCursorPos = function(x, y) end,
        write = function(text) io.write(text) end,
        clear = function() end
    }
end

if not shell then
    shell = {
        getRunningProgram = function()
            return "run_tests.lua"
        end
    }
end

if not fs then
    local lfs_ok, lfs = pcall(require, "lfs")

    if lfs_ok and lfs then
        fs = {
            exists = function(path)
                return lfs.attributes(path) ~= nil
            end,
            isDir = function(path)
                local attr = lfs.attributes(path)
                return attr and attr.mode == "directory"
            end,
            open = function(path, mode)
            local file = io.open(path, mode)
            if not file then return nil end
            return {
                readAll = function()
                    file:seek("set", 0)
                    return file:read("*a")
                end,
                read = function()
                    return file:read()
                end,
                write = function(text)
                    return file:write(text)
                end,
                close = function()
                    file:close()
                end,
                flush = function()
                    file:flush()
                end
            }
        end
    }
    else
        fs = {
            exists = function(path)
                local file = io.open(path, "r")
                if file then file:close() return true end
                return false
            end,
            isDir = function(path)
                return false
            end,
            open = function(path, mode)
                local file = io.open(path, mode)
                if not file then return nil end
                return {
                    readAll = function()
                        file:seek("set", 0)
                        return file:read("*a")
                    end,
                    read = function()
                        return file:read()
                    end,
                    write = function(text)
                        return file:write(text)
                    end,
                    close = function()
                        file:close()
                    end,
                    flush = function()
                        file:flush()
                    end
                }
            end
        }
    end
end

if not textutils then
    textutils = {
        serialize = function(tbl)
            local function serialize_value(val, indent)
                indent = indent or 0
                local indent_str = string.rep("  ", indent)
                local t = type(val)
                if t == "table" then
                    local result = "{\n"
                    for k, v in pairs(val) do
                        result = result .. indent_str .. "  " .. tostring(k) .. " = "
                        result = result .. serialize_value(v, indent + 1) .. ",\n"
                    end
                    result = result .. indent_str .. "}"
                    return result
                elseif t == "string" then
                    return string.format("%q", val)
                else
                    return tostring(val)
                end
            end
            return serialize_value(tbl)
        end,
        unserialize = function(str)
            local func = loadstring("return " .. str)
            if func then
                return func()
            end
            return nil
        end
    }
end

if not sleep then
    sleep = function(seconds)
        -- For testing, we can use os.execute or just return immediately
        -- os.execute("sleep " .. tostring(seconds))  -- Unix
        -- os.execute("timeout /t " .. tostring(seconds))  -- Windows
        -- For faster tests, we'll just return
    end
end

if not os then
    os = {}
end
if not os.date then
    local native_date = os.date
    local dateFunc
    if native_date then
        dateFunc = function(format)
            return native_date(format or "%c")
        end
    else
        dateFunc = function()
            return "Thu Jan 01 00:00:00 1970"
        end
    end
    os.date = dateFunc
end

local framework = require("tests.framework")

framework.enableLogging()

framework.logPrint("Running Quarry Test Suite")
framework.logPrint("=======================")

require("tests.test_utils")
require("tests.test_item_filter")
require("tests.test_fuel")
require("tests.test_inventory")
require("tests.test_tracker")
require("tests.test_mining")

framework.printStats()

if framework.saveLog("test.log") then
    framework.logPrint("Test log saved to test.log")
end
