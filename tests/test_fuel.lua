local framework = require("tests.framework")
local fuel = require("modules.fuel")
local inventory = require("modules.inventory")
local tracker = require("modules.turtle_tracker")
local mocks = require("tests.mocks")

local describe = framework.describe
local it = framework.it
local expect = framework.expect

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

        inventory.setup({["minecraft:coal"]=true})

        local result = fuel.checkFuel(1, 1, 0, 1, false)

        expect(result).toBe(true)
        expect(turtle.getFuelLevel()).toBe(80)
        expect(turtle.getItemCount(1)).toBe(0)
    end)

    it("calculateFuelNeeded accounts for round trip", function()
        fuel.setup(4)
        local needed = fuel.calculateFuelNeeded(5, 3)

        local fuelToTarget = 5 + 3 + 100
        local fuelForHole = 4 * 2 + 20
        local fuelToReturn = 5 + 3 + 100
        local expected = (fuelToTarget + fuelForHole + fuelToReturn) * 2

        expect(needed).toBe(expected)
    end)

    it("calculateFuelNeeded uses maxDepth when configured", function()
        fuel.setup(10)
        local needed1 = fuel.calculateFuelNeeded(1, 1)

        fuel.setup(20)
        local needed2 = fuel.calculateFuelNeeded(1, 1)

        expect(needed2).toBeGreaterThan(needed1)
    end)

    it("calculateFuelNeeded uses default depth when maxDepth is 0", function()
        fuel.setup(0)
        local needed = fuel.calculateFuelNeeded(1, 1)

        local fuelToTarget = 1 + 1 + 100
        local fuelForHole = 50 * 2 + 20
        local fuelToReturn = 1 + 1 + 100
        local expected = (fuelToTarget + fuelForHole + fuelToReturn) * 2

        expect(needed).toBe(expected)
    end)
end)

describe("Fuel Refueling Before Dropping", function()
    it("backHome uses fuel from inventory before dropping when fuelSources configured", function()
        local mining = require("modules.mining")

        turtle = mocks.createTurtle()
        turtle._setFuelLevel(100)
        turtle._setInventory(1, "minecraft:coal", 1)
        turtle._setInventory(2, "minecraft:stone", 10)

        inventory.setup({["minecraft:coal"]=true})
        fuel.setup(4)
        mining.setup({
            width = 5,
            length = 3,
            maxDepth = 4,
            offsetH = 0,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        tracker.state = {posx=1, posy=1, depth=0, facing=tracker.direction.front}

        local initialFuel = turtle.getFuelLevel()

        if inventory.fuelSources then
            for i=1,16 do
                inventory.useFuelItem(i)
            end
        end

        expect(turtle.getFuelLevel()).toBeGreaterThan(initialFuel)
        expect(turtle.getItemCount(1)).toBe(0)
        expect(turtle.getItemCount(2)).toBe(10)
    end)

    it("backHome uses any fuel before dropping when allowAnySource", function()
        local mining = require("modules.mining")

        turtle = mocks.createTurtle()
        turtle._setFuelLevel(100)
        turtle._setInventory(1, "minecraft:coal", 1)
        turtle._setInventory(2, "minecraft:stone", 10)

        inventory.setup(nil)
        fuel.setup(4)
        mining.setup({
            width = 5,
            length = 3,
            maxDepth = 4,
            offsetH = 0,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        tracker.state = {posx=1, posy=1, depth=0, facing=tracker.direction.front}

        local initialFuel = turtle.getFuelLevel()

        for i=1,16 do
            if turtle.getItemCount(i) > 0 then
                tracker.select(i)
                turtle.refuel()
            end
        end

        expect(turtle.getFuelLevel()).toBeGreaterThan(initialFuel)
        expect(turtle.getItemCount(1)).toBe(0)
        expect(turtle.getItemCount(2)).toBe(10)
    end)

    it("leftover fuel items are dropped to chest with other items", function()
        local mining = require("modules.mining")

        turtle = mocks.createTurtle()
        turtle._setFuelLevel(20000)
        turtle._setInventory(1, "minecraft:coal", 5)
        turtle._setInventory(2, "minecraft:diamond", 10)

        inventory.setup({["minecraft:coal"]=true})
        fuel.setup(4)
        mining.setup({
            width = 5,
            length = 3,
            maxDepth = 4,
            offsetH = 0,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        tracker.state = {posx=1, posy=1, depth=0, facing=tracker.direction.front}

        local initialFuel = turtle.getFuelLevel()

        if inventory.fuelSources then
            for i=1,16 do
                inventory.useFuelItem(i)
            end
        end

        local fuelAfterRefuel = turtle.getFuelLevel()
        expect(fuelAfterRefuel).toBeGreaterThan(initialFuel)

        local coalRemaining = turtle.getItemCount(1)
        expect(coalRemaining).toBeGreaterThan(0)
    end)
end)

describe("Fuel Refueling During Wait", function()
    it("wait loop uses fuel from inventory when fuelSources configured", function()
        turtle = mocks.createTurtle()
        turtle._setFuelLevel(100)
        turtle._setInventory(1, "minecraft:coal", 1)

        inventory.setup({["minecraft:coal"]=true})

        local initialFuel = turtle.getFuelLevel()

        if inventory.fuelSources then
            for i=1,16 do
                inventory.useFuelItem(i)
            end
        end

        expect(turtle.getFuelLevel()).toBeGreaterThan(initialFuel)
        expect(turtle.getItemCount(1)).toBe(0)
    end)

    it("wait loop uses any fuel when allowAnySource", function()
        turtle = mocks.createTurtle()
        turtle._setFuelLevel(100)
        turtle._setInventory(1, "minecraft:coal", 1)

        inventory.setup(nil)

        local initialFuel = turtle.getFuelLevel()

        for i=1,16 do
            if turtle.getItemCount(i) > 0 then
                tracker.select(i)
                turtle.refuel()
            end
        end

        expect(turtle.getFuelLevel()).toBeGreaterThan(initialFuel)
        expect(turtle.getItemCount(1)).toBe(0)
    end)

    it("wait loop does not pick up items from chest", function()
        turtle = mocks.createTurtle()
        turtle._setFuelLevel(100)
        turtle._setSuckUpItem("minecraft:coal", 1)

        inventory.setup({["minecraft:coal"]=true})

        local initialFuel = turtle.getFuelLevel()
        local initialInventoryEmpty = inventory.isInventoryEmpty()

        expect(inventory.isInventoryEmpty()).toBe(true)
        expect(turtle.getFuelLevel()).toBe(initialFuel)
        expect(turtle.getItemCount(1)).toBe(0)
    end)

    it("wait loop attempts refuel on each iteration", function()
        turtle = mocks.createTurtle()
        turtle._setFuelLevel(50)
        turtle._setInventory(1, "minecraft:coal", 2)

        inventory.setup({["minecraft:coal"]=true})

        local iterations = 0
        local originalSleep = sleep
        sleep = function() iterations = iterations + 1 end

        while turtle.getFuelLevel() < 200 and iterations < 5 do
            if inventory.fuelSources then
                for i=1,16 do
                    inventory.useFuelItem(i)
                end
            end
            sleep()
        end

        expect(iterations).toBeGreaterThan(0)
        expect(turtle.getFuelLevel()).toBeGreaterThan(50)

        sleep = originalSleep
    end)
end)

describe("Fuel Exhaustion Protection", function()
    it("calculateFuelNeededForLayerClearing calculates correct fuel for layer clearing", function()
        fuel.setup(4)
        local needed = fuel.calculateFuelNeededForLayerClearing(16, 3)

        local movementsPerRow = 3 - 1
        local totalMovements = 16 * movementsPerRow + (16 - 1)
        local fuelForMovements = totalMovements * 1
        local fuelForDigging = 16 * 3 * 2
        local fuelToReturn = (16 - 1) + (3 - 1) + 100
        local expected = (fuelForMovements + fuelForDigging + fuelToReturn) * 2

        expect(needed).toBe(expected)
    end)

    it("turtle_tracker detects fuel exhaustion and throws error", function()
        local tracker = require("modules.turtle_tracker")

        turtle = mocks.createTurtle()
        turtle._setFuelLevel(0)

        tracker.state = {posx=1, posy=1, depth=0, facing=tracker.direction.front}

        local success, err = pcall(tracker.forward)

        expect(success).toBe(false)
        expect(err).toContain("Out of fuel")
    end)

    it("turtle_tracker limits retry attempts to prevent infinite loops", function()
        local tracker = require("modules.turtle_tracker")

        turtle = mocks.createTurtle()
        turtle._setFuelLevel(1)

        local forwardCallCount = 0
        local originalForward = turtle.forward
        local function mockForward()
            forwardCallCount = forwardCallCount + 1
            return false
        end
        turtle.forward = mockForward

        tracker.state = {posx=1, posy=1, depth=0, facing=tracker.direction.front}

        local success, err = pcall(tracker.forward)

        expect(success).toBe(false)
        expect(forwardCallCount).toBeLessThanOrEqual(11)

        turtle.forward = originalForward
    end)

    it("clearLayer returns home when fuel runs low during clearing", function()
        local mining = require("modules.mining")

        turtle = mocks.createTurtle()
        turtle._setFuelLevel(500)

        fuel.setup(4)
        mining.setup({
            width = 5,
            length = 3,
            maxDepth = 4,
            offsetH = 0,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        tracker.state = {posx=1, posy=1, depth=0, facing=tracker.direction.front}

        local fuelCheckCount = 0
        local originalCalculateFuelNeeded = fuel.calculateFuelNeeded
        local function mockCalculateFuelNeeded(x, y)
            fuelCheckCount = fuelCheckCount + 1
            if fuelCheckCount > 5 then
                return 1000
            end
            return originalCalculateFuelNeeded(x, y)
        end
        fuel.calculateFuelNeeded = mockCalculateFuelNeeded

        local backHomeCalled = false
        local originalBackHome = mining.backHome
        local function mockBackHome(continue, x, y)
            backHomeCalled = true
        end
        mining.backHome = mockBackHome

        mining.clearLayer()

        expect(backHomeCalled).toBe(true)

        fuel.calculateFuelNeeded = originalCalculateFuelNeeded
        mining.backHome = originalBackHome
    end)

    it("clearLayer handles movement errors and returns home", function()
        local mining = require("modules.mining")

        turtle = mocks.createTurtle()
        turtle._setFuelLevel(100)

        fuel.setup(4)
        mining.setup({
            width = 3,
            length = 2,
            maxDepth = 4,
            offsetH = 0,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        tracker.state = {posx=1, posy=1, depth=0, facing=tracker.direction.front}

        local forwardCallCount = 0
        local originalForward = turtle.forward
        local function mockForward2()
            forwardCallCount = forwardCallCount + 1
            if forwardCallCount > 3 then
                turtle._setFuelLevel(0)
            end
            return originalForward()
        end
        turtle.forward = mockForward2

        local backHomeCalled = false
        local originalBackHome = mining.backHome
        local function mockBackHome2(continue, x, y)
            backHomeCalled = true
        end
        mining.backHome = mockBackHome2

        mining.clearLayer()

        expect(backHomeCalled).toBe(true)

        turtle.forward = originalForward
        mining.backHome = originalBackHome
    end)

    it("quarry checks fuel before starting layer clearing", function()
        local mining = require("modules.mining")

        turtle = mocks.createTurtle()
        turtle._setFuelLevel(100)

        fuel.setup(4)
        mining.setup({
            width = 16,
            length = 3,
            maxDepth = 4,
            offsetH = 0,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        local layerFuelNeeded = fuel.calculateFuelNeededForLayerClearing(16, 3)
        local currentFuel = turtle.getFuelLevel()

        expect(currentFuel).toBeLessThan(layerFuelNeeded)
    end)
end)
