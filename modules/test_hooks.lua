---@diagnostic disable: undefined-global
---@type table
fs = fs
---@type table
os = os

local M = {}

local enabled = false
local hooks = {}
local testResults = {
  holesDug = 0,
  refuelEvents = 0,
  backHomeCalls = 0,
  fuelWaitCycles = 0,
  positionChecks = {},
  errors = {}
}

function M.enable()
  enabled = true
  M.reset()
end

function M.disable()
  enabled = false
end

function M.reset()
  testResults = {
    holesDug = 0,
    refuelEvents = 0,
    backHomeCalls = 0,
    fuelWaitCycles = 0,
    positionChecks = {},
    errors = {}
  }
end

function M.onHoleComplete(x, y, holeCount)
  if not enabled then return end
  testResults.holesDug = holeCount
  table.insert(testResults.positionChecks, {type="hole", x=x, y=y, count=holeCount})

  if hooks.onHoleComplete then
    hooks.onHoleComplete(x, y, holeCount)
  end
end

function M.onRefuelAttempt(success, fuelLevel)
  if not enabled then return end
  testResults.refuelEvents = testResults.refuelEvents + 1

  if hooks.onRefuelAttempt then
    hooks.onRefuelAttempt(success, fuelLevel)
  end
end

function M.onFuelWait(needed, current)
  if not enabled then return end
  testResults.fuelWaitCycles = testResults.fuelWaitCycles + 1

  if hooks.onFuelWait then
    hooks.onFuelWait(needed, current)
  end
end

function M.onBackHome(continueAfterwards, targetX, targetY)
  if not enabled then return end
  testResults.backHomeCalls = testResults.backHomeCalls + 1

  if hooks.onBackHome then
    hooks.onBackHome(continueAfterwards, targetX, targetY)
  end
end

function M.onQuarryComplete(expectedHoles)
  if not enabled then return end

  if hooks.onQuarryComplete then
    hooks.onQuarryComplete(testResults.holesDug, expectedHoles)
  end

  M.saveResults()
end

function M.registerHook(name, callback)
  hooks[name] = callback
end

function M.getResults()
  return testResults
end

function M.saveResults()
  if not enabled then return false end

  local filename = "test_results.log"
  local file = fs.open(filename, "w")
  if not file then
    print("Warning: Could not create " .. filename)
    return false
  end

  file.write("Quarry Integration Test Results\n")
  file.write("================================\n\n")
  if os and os.date then
    file.write("Date: " .. os.date() .. "\n\n")
  end
  file.write("Holes Dug: " .. tostring(testResults.holesDug) .. "\n")
  file.write("Refuel Events: " .. tostring(testResults.refuelEvents) .. "\n")
  file.write("Back Home Calls: " .. tostring(testResults.backHomeCalls) .. "\n")
  file.write("Fuel Wait Cycles: " .. tostring(testResults.fuelWaitCycles) .. "\n")
  file.write("\nPosition Checks: " .. tostring(#testResults.positionChecks) .. "\n")
  if #testResults.positionChecks > 0 then
    file.write("\nPosition History:\n")
    for i, check in ipairs(testResults.positionChecks) do
      if i <= 50 then  -- Limit to first 50 to avoid huge files
        file.write(string.format("  %d: %s at (%d, %d)\n", i, check.type, check.x, check.y))
      end
    end
    if #testResults.positionChecks > 50 then
      file.write("  ... (" .. (#testResults.positionChecks - 50) .. " more)\n")
    end
  end
  if #testResults.errors > 0 then
    file.write("\nErrors:\n")
    for _, err in ipairs(testResults.errors) do
      file.write("  - " .. tostring(err) .. "\n")
    end
  else
    file.write("\nAll integration tests passed!\n")
  end
  file.close()

  print("Integration test results saved to " .. filename)
  return true
end

function M.assert(condition, message)
  if not enabled then return true end
  if not condition then
    table.insert(testResults.errors, message or "Assertion failed")
    return false
  end
  return true
end

return M
