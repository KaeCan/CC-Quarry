---@diagnostic disable: undefined-global
---@type table
turtle = turtle
---@type table
colors = colors
---@type function
sleep = sleep

local tracker = require("modules.turtle_tracker")
local filter = require("modules.item_filter")
local logger = require("modules.logger")
local M = {}

M.fuelSources = nil

-- possible drop-off blocks
-- (everything else with "chest" in the name will work too)
local dropSpots = {
  ["Railcraft:tile.railcraft.machine.beta"] = true,
  ["quark:pipe"] = true,
}

function M.setup(fuelSources)
  M.fuelSources = fuelSources
  if fuelSources then
    local fuelList = {}
    for name, _ in pairs(fuelSources) do
      table.insert(fuelList, name)
    end
    logger.log("Inventory module setup: fuelSources=" .. table.concat(fuelList, ", "))
  else
    logger.log("Inventory module setup: fuelSources=nil (any fuel allowed)")
  end
end

function M.itemName(slot)
  local details = turtle.getItemDetail(slot)
  return details and details.name
end

function M.itemDetails(slot)
  local details = turtle.getItemDetail(slot)
  return details and details.name.."#"..tostring(details.damage)
end

function M.useFuelItem(slot)
  local itemName = M.itemName(slot)
  local isFuelSource = M.fuelSources and M.fuelSources[itemName]
  logger.log("useFuelItem slot " .. tostring(slot) .. ": item=" .. tostring(itemName) ..
             " isFuelSource=" .. tostring(isFuelSource))
  if isFuelSource then
    tracker.select(slot)
    local success = turtle.refuel()
    logger.log("useFuelItem slot " .. tostring(slot) .. ": refuel result=" .. tostring(success))
    return success
  end
  return false
end

function M.dropWaste(slot)
  local details = turtle.getItemDetail(slot)
  if not details then return false end
  local item = details.name
  local isDesired = filter.isDesired(item)
  logger.log("dropWaste slot " .. tostring(slot) .. ": item=" .. tostring(item) ..
             " isDesired=" .. tostring(isDesired))
  if not isDesired then
    tracker.select(slot)
    local dropped = turtle.dropDown() or turtle.drop() or turtle.dropUp()
    logger.log("dropWaste slot " .. tostring(slot) .. ": drop result=" .. tostring(dropped))
    return dropped
  end
  return false
end

-- Drop waste items during compression (only down or forward, not up)
function M.dropWasteDuringCompression(slot)
  local details = turtle.getItemDetail(slot)
  if not details then return false end
  local item = details.name
  return not filter.isDesired(item)
         and tracker.select(slot)
         and (turtle.dropDown()
              or turtle.drop())
end

function M.getDropSpotName()
  local ok, data = turtle.inspectUp()
  if ok and (dropSpots[data.name] or data.name:lower():find("chest")) then
    return data.name
  end
end

function M.isInventoryEmpty()
  for i=1,16 do
    if turtle.getItemCount(i) > 0 then
      return false
    end
  end
  return true
end

function M.dropItemsInChest()
  local dropSpotName = M.getDropSpotName()
  logger.log("dropItemsInChest: looking for drop spot")
  while not dropSpotName do
    logger.log("dropItemsInChest: no drop spot found, waiting")
    logger.status("No inventory to drop items into...", colors.orange)
    sleep(3)
    dropSpotName = M.getDropSpotName()
  end

  logger.log("dropItemsInChest: found drop spot: " .. tostring(dropSpotName))
  logger.status("Dropping into \""..dropSpotName.."\"", colors.lightBlue, 0.5)
  local dropCycles = 0
  while true do
    dropCycles = dropCycles + 1
    local itemsDropped = 0
    for i=1,16 do
      if turtle.getItemCount(i) > 0 then
        if not M.dropWaste(i) then
          tracker.select(i)
          if turtle.dropUp() then
            itemsDropped = itemsDropped + 1
          end
        else
          itemsDropped = itemsDropped + 1
        end
      end
    end
    logger.log("dropItemsInChest: cycle " .. tostring(dropCycles) .. " dropped " .. tostring(itemsDropped) .. " items")
    if M.isInventoryEmpty() then
      logger.log("dropItemsInChest: inventory empty after " .. tostring(dropCycles) .. " cycles")
      break
    else
      sleep(3)
    end
  end
end

local function findInventoryGap()
  local gap = nil
  for i=1,16 do
    local empty = turtle.getItemCount(i) == 0
    if empty then
      gap = gap or i
    elseif gap then
      return gap
    end
  end
end

local function moveStack(src, dest)
  return
    tracker.select(src)
    and turtle.transferTo(dest)
    and turtle.getItemCount(src) == 0
end

local function defragInventory()
  for src=16,2,-1 do
    if turtle.getItemCount(src) > 0 then
      local srcName = M.itemDetails(src)
      for dest=1,src-1 do
        if (turtle.getItemCount(dest) == 0 or srcName == M.itemDetails(dest))
           and moveStack(src, dest) then
          break
        end
      end
    end
  end
  local gap = findInventoryGap()
  if gap then
    for src=16,gap+1,-1 do
      if turtle.getItemCount(src) > 0 then
        for dest=1,src-1 do
          if turtle.getItemCount(dest) == 0 and moveStack(src, dest) then
            break
          end
        end
      end
    end
  end
end

function M.compressInventory()
  logger.log("compressInventory: starting")
  local fuelUsed = 0
  local wasteDropped = 0
  for i=1,16 do
    if turtle.getItemCount(i) > 0 then
      if M.useFuelItem(i) then
        fuelUsed = fuelUsed + 1
      else
        local details = turtle.getItemDetail(i)
        if details and not filter.isDesired(details.name) then
          if M.dropWasteDuringCompression(i) then
            wasteDropped = wasteDropped + 1
          end
        end
      end
    end
  end
  logger.log("compressInventory: fuel used from " .. tostring(fuelUsed) .. " slots, waste dropped from " .. tostring(wasteDropped) .. " slots")
  defragInventory()
  logger.log("compressInventory: defragmentation complete")
end

function M.isInventoryFull()
  local slot16Count = turtle.getItemCount(16)
  logger.log("isInventoryFull: slot 16 count=" .. tostring(slot16Count))
  if slot16Count == 0 then
    logger.log("isInventoryFull: slot 16 empty, inventory not full")
    return false
  end
  logger.log("isInventoryFull: slot 16 has items, compressing")
  M.compressInventory()
  local slot14Count = turtle.getItemCount(14)
  local isFull = slot14Count > 0
  logger.log("isInventoryFull: after compression, slot 14 count=" .. tostring(slot14Count) .. " isFull=" .. tostring(isFull))
  return isFull
end

return M
