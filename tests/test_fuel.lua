local framework = require("tests.framework")
local fuel = require("modules.fuel")
local inventory = require("modules.inventory")
local mocks = require("tests.mocks")

local describe = framework.describe
local it = framework.it
local expect = framework.expect

-- We need to mock the turtle API for fuel.checkFuel
turtle = mocks.createTurtle()

describe("Fuel Module", function()

    it("calculateFuelNeeded returns correct estimate", function()
        -- Formula: (targetX + targetY + 100 + holeDepth*2 + 20 + targetX + targetY + 100) * 2
        -- Simplified: (2*targetX + 2*targetY + 200 + 2*holeDepth + 20) * 2

        fuel.setup(10) -- Max depth 10
        local needed = fuel.calculateFuelNeeded(1, 1)
        -- target=2, hole=10
        -- (1+1+100) = 102
        -- hole = 10*2 + 20 = 40
        -- return = 102
        -- total = (102 + 40 + 102) * 2 = 244 * 2 = 488
        expect(needed).toBe(488)
    end)

    it("checkFuel returns true if fuel is sufficient", function()
        turtle._setFuelLevel(10000)
        -- posx=1, posy=1, depth=0, factor=1
        -- needed = (0 + 1 + 1 + 100) * 1 = 102
        expect(fuel.checkFuel(1, 1, 0, 1, false)).toBe(true)
    end)

    it("checkFuel attempts refuel if low", function()
        turtle._setFuelLevel(0)
        turtle._setInventory(1, "minecraft:coal", 1)

        -- Set up inventory with fuel sources so useFuelItem works
        inventory.setup({["minecraft:coal"]=true})

        -- Should consume coal
        local result = fuel.checkFuel(1, 1, 0, 1, false)

        expect(result).toBe(true)
        expect(turtle.getFuelLevel()).toBe(80)
        expect(turtle.getItemCount(1)).toBe(0)
    end)
end)
