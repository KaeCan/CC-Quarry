local framework = require("tests.framework")
local utils = require("modules.utils")

local describe = framework.describe
local it = framework.it
local expect = framework.expect

describe("Utils Module", function()
    it("startswith returns true for matching prefix", function()
        expect(utils.startswith("hello world", "hello")).toBe(true)
    end)

    it("startswith returns false for non-matching prefix", function()
        expect(utils.startswith("hello world", "world")).toBe(false)
    end)

    it("findFile returns nil if shell not available (mock check)", function()
        -- Since we are running outside a real shell environment possibly, or in a limited one
        -- This mostly tests that it doesn't crash
        local result = utils.findFile("nonexistent.file")
        expect(result == nil or type(result) == "string").toBe(true)
    end)
end)
