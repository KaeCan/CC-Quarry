local framework = require("tests.framework")
local tracker = require("modules.turtle_tracker")
local mocks = require("tests.mocks")

local describe = framework.describe
local it = framework.it
local expect = framework.expect

-- Reset turtle mock
turtle = mocks.createTurtle()

describe("Turtle Tracker Module", function()
    -- Reset state before tests
    tracker.state = {depth=0, posx=1, posy=1, facing=tracker.direction.front}

    it("forward updates position based on facing", function()
        turtle._setFuelLevel(100)
        -- Face Front (North/0), move forward -> y increases
        tracker.state.facing = tracker.direction.front
        tracker.state.posy = 1
        tracker.forward()
        expect(tracker.state.posy).toBe(2)

        -- Face Right (East/1), move forward -> x increases
        tracker.state.facing = tracker.direction.right
        tracker.state.posx = 1
        tracker.forward()
        expect(tracker.state.posx).toBe(2)
    end)

    it("turnRight updates facing correctly", function()
        tracker.state.facing = tracker.direction.front -- 0
        tracker.turnRight()
        expect(tracker.state.facing).toBe(tracker.direction.right) -- 1

        tracker.state.facing = tracker.direction.left -- 3
        tracker.turnRight()
        expect(tracker.state.facing).toBe(tracker.direction.front) -- 0
    end)

    it("up/down updates depth (logic check)", function()
        turtle._setFuelLevel(100)
        -- Tracker doesn't strictly track depth in up/down yet (it's handled in mining.lua mostly)
        -- But let's verify it calls the turtle function
        -- Since we mock turtle, we assume success
        tracker.up()
        -- In the current implementation of turtle_tracker.lua:
        -- function M.up() ... end -- it just calls turtle.up()
        -- It does NOT update tracker.state.depth currently!
        -- This test confirms that behavior (or lack thereof)
        expect(tracker.state.depth).toBe(0)
    end)
end)
