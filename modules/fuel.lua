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
  logger.log("Fuel module setup: maxDepth=" .. tostring(maxDepth))
end

function M.checkFuel(posx, posy, depth, factor, allowAnySource)
  local currentFuel = turtle.getFuelLevel()
  local requiredFuel = (depth + posx + posy + 100) * factor
  logger.log("checkFuel: pos (" .. tostring(posx) .. "," .. tostring(posy) .. ") depth=" .. tostring(depth) ..
             " factor=" .. tostring(factor) .. " current=" .. tostring(currentFuel) ..
             " required=" .. tostring(requiredFuel) .. " allowAnySource=" .. tostring(allowAnySource))

  if currentFuel <= requiredFuel then
    logger.log("checkFuel: fuel low, attempting refuel")
    logger.status("Need fuel, trying to fill up...", colors.lightBlue, 0.5)
    local refuelFn = allowAnySource and turtle.refuel or inventory.useFuelItem
    local success = false
    local refueledSlots = 0
    for i=1,16 do
      if turtle.getItemCount(i) > 0 then
        tracker.select(i)
        local slotSuccess = refuelFn(i)
        if slotSuccess then
          refueledSlots = refueledSlots + 1
          logger.log("checkFuel: refueled from slot " .. tostring(i))
        end
        success = slotSuccess or success
      end
    end
    local newFuel = turtle.getFuelLevel()
    logger.log("checkFuel: refuel attempt complete, success=" .. tostring(success) ..
               " slots used=" .. tostring(refueledSlots) .. " new fuel=" .. tostring(newFuel))
    local color = success and colors.lime or colors.orange
    local text = "Refuel success: "..tostring(success)
    if success then
      text = text.." ("..tostring(newFuel)..")"
    end
    logger.status(text, color, 0.5)
    testHooks.onRefuelAttempt(success, newFuel)
    return success
  end
  logger.log("checkFuel: fuel sufficient")
  return true
end

function M.calculateFuelNeeded(targetX, targetY)
  local fuelToTarget = targetX + targetY + 100
  local holeDepth = config.maxDepth > 0 and config.maxDepth or 50
  local fuelForHole = holeDepth * 2 + 20
  local fuelToReturn = targetX + targetY + 100
  local totalFuel = (fuelToTarget + fuelForHole + fuelToReturn) * 2
  logger.log("calculateFuelNeeded: target (" .. tostring(targetX) .. "," .. tostring(targetY) ..
             ") holeDepth=" .. tostring(holeDepth) .. " total=" .. tostring(totalFuel))
  return totalFuel
end

function M.calculateFuelNeededForLayerClearing(width, length)
  local movementsPerRow = length - 1
  local totalMovements = width * movementsPerRow + (width - 1)
  local fuelForMovements = totalMovements * 1
  local fuelForDigging = width * length * 2
  local fuelToReturn = (width - 1) + (length - 1) + 100
  local totalFuel = (fuelForMovements + fuelForDigging + fuelToReturn) * 2
  logger.log("calculateFuelNeededForLayerClearing: width=" .. tostring(width) .. " length=" .. tostring(length) ..
             " movements=" .. tostring(totalMovements) .. " total=" .. tostring(totalFuel))
  return totalFuel
end

return M
