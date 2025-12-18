local framework = require("tests.framework")
local filter = require("modules.item_filter")

local describe = framework.describe
local it = framework.it
local expect = framework.expect

describe("Item Filter Module", function()

    it("isDesired returns true when no lists configured", function()
        filter.setup(nil, nil)
        expect(filter.isDesired("minecraft:stone", nil)).toBe(true)
    end)

    it("isDesired respects allow list", function()
        local allow = {["minecraft:diamond"] = true}
        filter.setup(allow, nil)

        expect(filter.isDesired("minecraft:diamond", nil)).toBe(true)
        expect(filter.isDesired("minecraft:stone", nil)).toBe(false)
    end)

    it("isDesired respects ignore list", function()
        local ignore = {["minecraft:cobblestone"] = true}
        filter.setup(nil, ignore)

        expect(filter.isDesired("minecraft:diamond", nil)).toBe(true)
        expect(filter.isDesired("minecraft:cobblestone", nil)).toBe(false)
    end)

    it("allow list takes precedence over ignore list", function()
        local allow = {["minecraft:gold_ore"] = true}
        local ignore = {["minecraft:gold_ore"] = true} -- Should theoretically not happen in user config but good to test logic
        filter.setup(allow, ignore)

        expect(filter.isDesired("minecraft:gold_ore", nil)).toBe(true)
        expect(filter.isDesired("minecraft:stone", nil)).toBe(false)
    end)

    it("matches tags in allow list", function()
        -- Mock block data with tags
        local blockData = {
            name = "minecraft:oak_log",
            tags = {["minecraft:logs"] = true}
        }

        local allow = {["tag@minecraft:logs"] = true}
        filter.setup(allow, nil)

        expect(filter.isDesired(blockData.name, blockData)).toBe(true)
    end)
end)
