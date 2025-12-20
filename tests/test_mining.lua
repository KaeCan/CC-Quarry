local framework = require("tests.framework")
local mining = require("modules.mining")
local filter = require("modules.item_filter")
local tracker = require("modules.turtle_tracker")
local mocks = require("tests.mocks")

local describe = framework.describe
local it = framework.it
local expect = framework.expect

-- Enhanced mock turtle that tracks dig calls
local function createMiningTurtle()
    local mock = mocks.createTurtle()
    local digCalls = {}
    local detectResults = {}
    local inspectResults = {}
    local detectCallCount = 0
    local inspectCallCount = 0

    -- Store original functions in closure
    local originalDig = mock.dig

    -- Track dig calls
    local function trackedDig()
        table.insert(digCalls, "front")
        return originalDig()
    end
    mock.dig = trackedDig

    -- Configurable detect() behavior
    local function configurableDetect()
        detectCallCount = detectCallCount + 1
        local result = detectResults[detectCallCount]
        if result == nil then
            return false  -- Default: no block detected
        end
        return result
    end
    mock.detect = configurableDetect

    -- Configurable inspect() behavior
    local function configurableInspect()
        inspectCallCount = inspectCallCount + 1
        local result = inspectResults[inspectCallCount]
        if result == nil then
            return false, "No block to inspect"
        end
        if result == false then
            return false, "No block to inspect"
        end
        return true, result
    end
    mock.inspect = configurableInspect

    -- Test helpers
    function mock._setDetectResults(...)
        detectResults = {...}
        detectCallCount = 0
    end

    function mock._setInspectResults(...)
        inspectResults = {...}
        inspectCallCount = 0
    end

    function mock._getDigCalls()
        return digCalls
    end

    function mock._resetDigCalls()
        digCalls = {}
    end

    function mock._reset()
        detectCallCount = 0
        inspectCallCount = 0
        digCalls = {}
        detectResults = {}
        inspectResults = {}
    end

    return mock
end

describe("Mining Module - Filter Integration", function()

    it("hasFilters returns false when no filters configured", function()
        filter.setup(nil, nil)
        expect(filter.hasFilters()).toBe(false)
    end)

    it("hasFilters returns true when allow list configured", function()
        filter.setup({["minecraft:diamond"] = true}, nil)
        expect(filter.hasFilters()).toBe(true)
    end)

    it("hasFilters returns true when ignore list configured", function()
        filter.setup(nil, {["minecraft:stone"] = true})
        expect(filter.hasFilters()).toBe(true)
    end)

    it("digSides respects allow list - mines only allowed blocks", function()
        turtle = createMiningTurtle()
        tracker.state = {depth=0, posx=1, posy=1, facing=tracker.direction.front}

        -- Set up allow list: only mine diamond
        local allow = {["minecraft:diamond"] = true}
        filter.setup(allow, nil)

        -- Set up mining config
        mining.setup({
            width = 1,
            length = 1,
            offsetH = 0,
            maxDepth = 1,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        turtle._setFuelLevel(10000)
        turtle._resetDigCalls()

        -- Mock down() to succeed once, then fail (simulates going down one level then hitting bottom)
        local downCallCount = 0
        local originalDown = turtle.down
        turtle.down = function()
            downCallCount = downCallCount + 1
            if downCallCount == 1 then
                -- First call succeeds (moves down one level)
                return true
            else
                -- Second call fails (hits bottom)
                return false
            end
        end

        -- Mock detectDown() to return false (no block below initially, then after moving down)
        local originalDetectDown = turtle.detectDown
        turtle.detectDown = function()
            return false  -- No block below
        end

        -- When digSides is called, set up the side blocks
        -- Side 1: diamond (should mine)
        -- Side 2: stone (should NOT mine)
        -- Side 3: diamond (should mine)
        -- Side 4: cobblestone (should NOT mine)
        turtle._setDetectResults(true, true, true, true)
        turtle._setInspectResults(
            {name = "minecraft:diamond"},      -- Side 1: allowed
            {name = "minecraft:stone"},        -- Side 2: not allowed
            {name = "minecraft:diamond"},      -- Side 3: allowed
            {name = "minecraft:cobblestone"}  -- Side 4: not allowed
        )

        mining.digColumn()

        -- Verify: should have mined 2 blocks (the two diamonds)
        local digCalls = turtle._getDigCalls()
        expect(#digCalls).toBe(2)  -- Only the two diamonds should be mined

        -- Restore
        turtle.down = originalDown
        turtle.detectDown = originalDetectDown
    end)

    it("digSides respects ignore list - skips ignored blocks", function()
        turtle = createMiningTurtle()
        tracker.state = {depth=0, posx=1, posy=1, facing=tracker.direction.front}

        -- Set up ignore list: ignore stone and cobblestone
        local ignore = {
            ["minecraft:stone"] = true,
            ["minecraft:cobblestone"] = true
        }
        filter.setup(nil, ignore)

        -- Set up mining config
        mining.setup({
            width = 1,
            length = 1,
            offsetH = 0,
            maxDepth = 1,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        turtle._setFuelLevel(10000)
        turtle._resetDigCalls()

        -- Mock down() to succeed once, then fail
        local downCallCount = 0
        local originalDown = turtle.down
        turtle.down = function()
            downCallCount = downCallCount + 1
            if downCallCount == 1 then
                return true
            else
                return false
            end
        end

        -- Mock detectDown() to return false
        local originalDetectDown = turtle.detectDown
        turtle.detectDown = function()
            return false
        end

        -- When digSides is called, set up the side blocks
        -- Side 1: diamond (should mine - not ignored)
        -- Side 2: stone (should NOT mine - ignored)
        -- Side 3: cobblestone (should NOT mine - ignored)
        -- Side 4: gold_ore (should mine - not ignored)
        turtle._setDetectResults(true, true, true, true)
        turtle._setInspectResults(
            {name = "minecraft:diamond"},      -- Side 1: not ignored
            {name = "minecraft:stone"},        -- Side 2: ignored
            {name = "minecraft:cobblestone"},  -- Side 3: ignored
            {name = "minecraft:gold_ore"}      -- Side 4: not ignored
        )

        mining.digColumn()

        -- Verify: should have mined 2 blocks (diamond and gold_ore)
        local digCalls = turtle._getDigCalls()
        expect(#digCalls).toBe(2)  -- Only diamond and gold_ore should be mined

        -- Restore
        turtle.down = originalDown
        turtle.detectDown = originalDetectDown
    end)

    it("digSides mines all blocks when no filters configured", function()
        turtle = createMiningTurtle()
        tracker.state = {depth=0, posx=1, posy=1, facing=tracker.direction.front}

        -- No filters configured
        filter.setup(nil, nil)

        -- Set up mining config
        mining.setup({
            width = 1,
            length = 1,
            offsetH = 0,
            maxDepth = 1,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        turtle._setFuelLevel(10000)
        turtle._resetDigCalls()

        -- Mock down() to succeed once, then fail
        local downCallCount = 0
        local originalDown = turtle.down
        turtle.down = function()
            downCallCount = downCallCount + 1
            if downCallCount == 1 then
                return true
            else
                return false
            end
        end

        -- Mock detectDown() to return false
        local originalDetectDown = turtle.detectDown
        turtle.detectDown = function()
            return false
        end

        -- Mock: detect blocks on all 4 sides
        turtle._setDetectResults(true, true, true, true)

        mining.digColumn()

        -- Verify: should have mined all 4 blocks (no filtering)
        local digCalls = turtle._getDigCalls()
        expect(#digCalls).toBe(4)  -- All blocks should be mined when no filters

        -- Restore
        turtle.down = originalDown
        turtle.detectDown = originalDetectDown
    end)

    it("digSides does not mine when inspection fails", function()
        turtle = createMiningTurtle()
        tracker.state = {depth=0, posx=1, posy=1, facing=tracker.direction.front}

        -- Set up allow list
        local allow = {["minecraft:diamond"] = true}
        filter.setup(allow, nil)

        -- Set up mining config
        mining.setup({
            width = 1,
            length = 1,
            offsetH = 0,
            maxDepth = 1,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        turtle._setFuelLevel(10000)
        turtle._resetDigCalls()

        -- Mock down() to succeed once, then fail
        local downCallCount = 0
        local originalDown = turtle.down
        turtle.down = function()
            downCallCount = downCallCount + 1
            if downCallCount == 1 then
                return true
            else
                return false
            end
        end

        -- Mock detectDown() to return false
        local originalDetectDown = turtle.detectDown
        turtle.detectDown = function()
            return false
        end

        -- Mock: detect blocks but inspection fails
        turtle._setDetectResults(true, true, true, true)
        turtle._setInspectResults(false, false, false, false)  -- All inspections fail

        mining.digColumn()

        -- Verify: should NOT mine any blocks (inspection failed)
        local digCalls = turtle._getDigCalls()
        expect(#digCalls).toBe(0)  -- No blocks should be mined when inspection fails

        -- Restore
        turtle.down = originalDown
        turtle.detectDown = originalDetectDown
    end)
end)
describe("Mining Module - Boundary Handling", function()
    it("calculateSkipOffset: Y stays within bounds when transitioning rows (front to back)", function()
        -- Start at (1,1) facing front, can't move +5, so should go to next row
        mining.setup({
            width = 16,
            length = 3,
            offsetH = 0,
            maxDepth = 4,
            skipHoles = 1,  -- Skip 1 hole: (1,1) -> R2 (Back)
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        local x, y, facing, running = mining.calculateSkipOffset()

        -- Verify Y is within bounds and correct
        -- Row 2 shift: ((2-1)*3 + 1) % 5 = 4.
        -- Length 3.
        -- k = floor((3-4)/5) = -1. Wait...
        -- The logic was: nextY = shift + k*5.
        -- If shift (4) > length (3), then k=-1. nextY = 4-5 = -1.
        -- M.nextHole will skip this row if nextY is invalid.
        -- So it should go to Row 3 (Front).
        -- Row 3 shift: ((3-1)*3 + 1) % 5 = 2.
        -- nextY = 2. Valid.
        -- So expected: x=3, y=2, facing=Front.

        expect(y >= 1).toBe(true)
        expect(y <= 3).toBe(true)
        expect(x).toBe(3)
        expect(y).toBe(2)
        expect(facing).toBe(tracker.direction.front)
    end)

    it("calculateSkipOffset: Y stays within bounds when transitioning rows (back to front)", function()
        -- We need to setup a state where we are in a Back row and move to Front row.
        -- Let's aim for Row 2 -> Row 3.
        -- R2 (Back). Shift 4. Length 16.
        -- Holes: 14, 9, 4.
        -- Let's skip to the end of R2.
        -- Holes so far: R1 (1, 6, 11, 16) -> 4 holes.
        -- R2 (14, 9, 4) -> 3 holes. Total 7.
        -- So skip 7 holes. Should be at start of R3 (3, 2).

        mining.setup({
            width = 16,
            length = 16,
            offsetH = 0,
            maxDepth = 4,
            skipHoles = 7,  -- Skip R1 and R2.
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        local x, y, facing, running = mining.calculateSkipOffset()

        -- Should be at start of R3.
        -- R3 shift: ((3-1)*3 + 1)%5 = 7%5 = 2.
        -- Start Y = 2.
        expect(x).toBe(3)
        expect(y).toBe(2)
        expect(facing).toBe(tracker.direction.front)
    end)

    it("calculateSkipOffset: handles small length correctly (length=3)", function()
        mining.setup({
            width = 16,
            length = 3,
            offsetH = 0,
            maxDepth = 4,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        -- Test multiple transitions
        for skipCount = 0, 10 do
            mining.setup({
                width = 16,
                length = 3,
                offsetH = 0,
                maxDepth = 4,
                skipHoles = skipCount,
                rememberBlocks = false,
                minedBlocks = {},
                holeCount = 0
            })

            local x, y, facing, running = mining.calculateSkipOffset()

            -- Y must always be between 1 and 3
            expect(y >= 1).toBe(true)
            expect(y <= 3).toBe(true)
            -- X must not exceed width
            expect(x <= 16).toBe(true)
        end
    end)

    it("calculateSkipOffset: never produces negative Y coordinates", function()
        mining.setup({
            width = 5,
            length = 2,  -- Very small length
            offsetH = 0,
            maxDepth = 4,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        -- Test many transitions to catch any negative Y
        for skipCount = 0, 20 do
            mining.setup({
                width = 5,
                length = 2,
                offsetH = 0,
                maxDepth = 4,
                skipHoles = skipCount,
                rememberBlocks = false,
                minedBlocks = {},
                holeCount = 0
            })

            local x, y, facing, running = mining.calculateSkipOffset()

            expect(y >= 1).toBe(true)  -- Must never be negative
            expect(y <= 2).toBe(true)  -- Must never exceed length
        end
    end)

    it("calculateSkipOffset: never exceeds length boundary", function()
        mining.setup({
            width = 10,
            length = 3,
            offsetH = 0,
            maxDepth = 4,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        -- Test many transitions
        for skipCount = 0, 30 do
            mining.setup({
                width = 10,
                length = 3,
                offsetH = 0,
                maxDepth = 4,
                skipHoles = skipCount,
                rememberBlocks = false,
                minedBlocks = {},
                holeCount = 0
            })

            local x, y, facing, running = mining.calculateSkipOffset()

            expect(y <= 3).toBe(true)  -- Must never exceed length
            expect(y >= 1).toBe(true)   -- Must never be less than 1
        end
    end)

    it("calculateSkipOffset: correctly transitions from front to back at row boundary", function()
        mining.setup({
            width = 16,
            length = 16,
            offsetH = 0,
            maxDepth = 4,
            skipHoles = 4,  -- Skip R1 (4 holes: 1, 6, 11, 16). Should be start of R2.
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        local x, y, facing, running = mining.calculateSkipOffset()

        -- Start of R2 (Back). Shift 4.
        -- Max Y <= 16 matching 4+k*5.
        -- 4 + 2*5 = 14.
        expect(x).toBe(2)
        expect(y).toBe(14)
        expect(facing).toBe(tracker.direction.back)
    end)

    it("calculateSkipOffset: correctly transitions from back to front at row boundary", function()
        mining.setup({
            width = 16,
            length = 16,
            offsetH = 0,
            maxDepth = 4,
            skipHoles = 7,  -- Skip R1 (4) + R2 (3: 14, 9, 4). Total 7. Start of R3.
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        local x, y, facing, running = mining.calculateSkipOffset()

        -- Start of R3 (Front). Shift 2.
        expect(x).toBe(3)
        expect(y).toBe(2)
        expect(facing).toBe(tracker.direction.front)
    end)

    it("calculateSkipOffset: handles edge case at last row correctly", function()
        mining.setup({
            width = 3,
            length = 3,
            offsetH = 0,
            maxDepth = 4,
            skipHoles = 0,
            rememberBlocks = false,
            minedBlocks = {},
            holeCount = 0
        })

        -- Test skipping to positions near the last row
        for skipCount = 0, 10 do
            mining.setup({
                width = 3,
                length = 3,
                offsetH = 0,
                maxDepth = 4,
                skipHoles = skipCount,
                rememberBlocks = false,
                minedBlocks = {},
                holeCount = 0
            })

            local x, y, facing, running = mining.calculateSkipOffset()

            -- X should never exceed width
            expect(x <= 3).toBe(true)
            -- Y should always be valid
            expect(y >= 1).toBe(true)
            expect(y <= 3).toBe(true)
        end
    end)
end)

describe("Mining Module - Pattern Verification", function()
    it("generates correct sequence for 8x3 grid (Knight's move pattern)", function()
        local sequence = {}
        local x, y, facing = 1, 1, tracker.direction.front
        table.insert(sequence, {x, y})

        while true do
            local nx, ny, nf = mining.nextHole(x, y, facing, 8, 3)
            if not nx then break end
            x, y, facing = nx, ny, nf
            table.insert(sequence, {x, y})
        end

        local expected = {
            {1, 1},
            {3, 2},
            {5, 3},
            {6, 1},
            {8, 2}
        }

        expect(#sequence).toBe(#expected)
        for i, pos in ipairs(sequence) do
            expect(pos[1]).toBe(expected[i][1])
            expect(pos[2]).toBe(expected[i][2])
        end
    end)

    it("generates correct sequence for 3x3 grid", function()
        local sequence = {}
        local x, y, facing = 1, 1, tracker.direction.front
        table.insert(sequence, {x, y})

        while true do
            local nx, ny, nf = mining.nextHole(x, y, facing, 3, 3)
            if not nx then break end
            x, y, facing = nx, ny, nf
            table.insert(sequence, {x, y})
        end

        local expected = {
            {1, 1},
            {3, 2}
        }

        expect(#sequence).toBe(#expected)
        for i, pos in ipairs(sequence) do
            expect(pos[1]).toBe(expected[i][1])
            expect(pos[2]).toBe(expected[i][2])
        end
    end)
end)
