---@diagnostic disable: undefined-global
---@type table
colors = colors

local inventory = require("modules.inventory")
local tracker = require("modules.turtle_tracker")
local logger = require("modules.logger")
local testHooks = require("modules.test_hooks")

local M = {}

local config = {
  maxDepth = 0
}

function M.setup(maxDepth)
  config.maxDepth = maxDepth
end

function M.checkFuel(posx, posy, depth, factor, allowAnySource)
  if turtle.getFuelLevel() <= ((depth + posx + posy + 100) * factor) then
    logger.status("Need fuel, trying to fill up...", colors.lightBlue, 0.5)
    local refuelFn = allowAnySource and turtle.refuel or inventory.useFuelItem
    local success = false
    for i=1,16 do
      if turtle.getItemCount(i) > 0 then
        tracker.select(i)
        success = refuelFn(i) or success
      end
    end
    local color = success and colors.lime or colors.orange
    local text = "Refuel success: "..tostring(success)
    if success then
      text = text.." ("..tostring(turtle.getFuelLevel())..")"
    end
    logger.status(text, color, 0.5)
    testHooks.onRefuelAttempt(success, turtle.getFuelLevel())
    return success
  end
  return true
end

function M.calculateFuelNeeded(targetX, targetY)
  local fuelToTarget = targetX + targetY + 100
  local holeDepth = config.maxDepth > 0 and config.maxDepth or 50
  local fuelForHole = holeDepth * 2 + 20
  local fuelToReturn = targetX + targetY + 100
  return (fuelToTarget + fuelForHole + fuelToReturn) * 2
end

return M
