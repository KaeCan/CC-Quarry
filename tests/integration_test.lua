---@diagnostic disable: undefined-global, lowercase-global
---@type table
turtle = turtle
---@type table
fs = fs

local testHooks = require("modules.test_hooks")
local tracker = require("modules.turtle_tracker")
local mining = require("modules.mining")

local M = {}

local expectedHoles = 0
local lastHolePosition = nil
local refuelWaitStarted = false
local refuelWaitCompleted = false
local lastFuelNeeded = 0

function M.calculateExpectedHoles(width, length)
  local holes = 0
  local x = 1
  local y = 1
  local facing = 0

  while true do
    holes = holes + 1

    if x == width then
      if (facing == 0 and (y + 5) > length) or (facing == 2 and (y - 5) < 1) then
        break
      end
    end

    if facing == 0 then
      if y + 5 <= length then
        y = y + 5
      elseif y + 3 <= length then
        y = y + 3
        x = x + 1
        facing = 2
      else
        x = x + 1
        facing = 2
        y = y - 2
      end
    elseif facing == 2 then
      if y - 5 >= 1 then
        y = y - 5
      elseif y - 2 >= 1 then
        y = y - 2
        x = x + 1
        facing = 0
      else
        x = x + 1
        facing = 0
        y = y + 3
      end
    end

    if x > width then
      break
    end
  end

  return holes
end

function M.setup(width, length)
  expectedHoles = M.calculateExpectedHoles(width, length)
  testHooks.reset()

  testHooks.registerHook("onHoleComplete", function(x, y, count)
    lastHolePosition = {x=x, y=y}

    testHooks.assert(count > 0, "Hole count should be positive")
    testHooks.assert(x >= 1 and x <= width, "Hole X position out of bounds: " .. tostring(x))
    testHooks.assert(y >= 1 and y <= length, "Hole Y position out of bounds: " .. tostring(y))
  end)

  testHooks.registerHook("onFuelWait", function(needed, current)
    refuelWaitStarted = true
    lastFuelNeeded = needed
    testHooks.assert(needed > 0, "Fuel needed should be positive")
    testHooks.assert(current >= 0, "Current fuel should be non-negative")
  end)

  testHooks.registerHook("onRefuelAttempt", function(success, fuelLevel)
    if refuelWaitStarted and not refuelWaitCompleted then
      if fuelLevel >= lastFuelNeeded then
        refuelWaitCompleted = true
        testHooks.assert(true, "Fuel wait cycle completed successfully")
      end
    end
  end)

  testHooks.registerHook("onBackHome", function(continueAfterwards, targetX, targetY)
    if continueAfterwards then
      testHooks.assert(targetX ~= nil, "Target X should be set when continuing")
      testHooks.assert(targetY ~= nil, "Target Y should be set when continuing")
    end
  end)

  testHooks.registerHook("onQuarryComplete", function(actualHoles, expected)
    testHooks.assert(actualHoles == expected,
      string.format("Expected %d holes, but dug %d", expected, actualHoles))

    local state = tracker.state
    testHooks.assert(state.posx == 1, "Should end at X=1, but was " .. tostring(state.posx))
    testHooks.assert(state.posy == 1, "Should end at Y=1, but was " .. tostring(state.posy))
    testHooks.assert(state.depth == 0, "Should end at depth=0, but was " .. tostring(state.depth))
  end)
end

function M.printResults()
  local results = testHooks.getResults()
  print("\n=== Integration Test Results ===")
  print("Holes Dug: " .. tostring(results.holesDug) .. " (Expected: " .. tostring(expectedHoles) .. ")")
  print("Refuel Events: " .. tostring(results.refuelEvents))
  print("Back Home Calls: " .. tostring(results.backHomeCalls))
  print("Fuel Wait Cycles: " .. tostring(results.fuelWaitCycles))

  if #results.errors > 0 then
    print("\nErrors:")
    for _, err in ipairs(results.errors) do
      print("  - " .. tostring(err))
    end
  else
    print("\nAll tests passed!")
  end
end

return M
