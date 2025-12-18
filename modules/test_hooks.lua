---@diagnostic disable: undefined-global
---@type table
fs = fs

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
  local file = fs.open("test_results.txt", "w")
  if file then
    file.write("Quarry Integration Test Results\n")
    file.write("================================\n\n")
    file.write("Holes Dug: " .. tostring(testResults.holesDug) .. "\n")
    file.write("Refuel Events: " .. tostring(testResults.refuelEvents) .. "\n")
    file.write("Back Home Calls: " .. tostring(testResults.backHomeCalls) .. "\n")
    file.write("Fuel Wait Cycles: " .. tostring(testResults.fuelWaitCycles) .. "\n")
    file.write("\nPosition Checks: " .. tostring(#testResults.positionChecks) .. "\n")
    if #testResults.errors > 0 then
      file.write("\nErrors:\n")
      for _, err in ipairs(testResults.errors) do
        file.write("  - " .. tostring(err) .. "\n")
      end
    end
    file.close()
  end
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
