local framework = require("tests.framework")
local inventory = require("modules.inventory")
local filter = require("modules.item_filter")
local mocks = require("tests.mocks")

local describe = framework.describe
local it = framework.it
local expect = framework.expect

-- Reset turtle mock
turtle = mocks.createTurtle()

describe("Inventory Module", function()

    it("isInventoryEmpty returns true for empty inventory", function()
        expect(inventory.isInventoryEmpty()).toBe(true)
    end)

    it("isInventoryEmpty returns false for occupied inventory", function()
        turtle._setInventory(1, "minecraft:stone", 64)
        expect(inventory.isInventoryEmpty()).toBe(false)
        turtle._setInventory(1, nil, 0) -- cleanup
    end)

    it("isInventoryFull checks slot 16 and compression", function()
        -- Setup full inventory
        for i=1,16 do
            turtle._setInventory(i, "minecraft:cobblestone", 64)
        end

        -- Mark cobble as ignored so it can be dropped?
        -- By default filter allows everything if no lists.
        -- Let's set ignore list
        filter.setup(nil, {["minecraft:cobblestone"]=true})

        -- isInventoryFull calls compressInventory which drops waste
        -- So if we run it, it should empty the inventory and return false
        local full = inventory.isInventoryFull()

        expect(full).toBe(false)
        expect(turtle.getItemCount(1)).toBe(0) -- Should have dropped everything
    end)
end)
