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
  return M.fuelSources
         and M.fuelSources[M.itemName(slot)]
         and tracker.select(slot)
         and turtle.refuel()
end

function M.dropWaste(slot)
  local details = turtle.getItemDetail(slot)
  if not details then return false end
  local item = details.name
  return not filter.isDesired(item)
         and tracker.select(slot)
         and (turtle.dropDown()
              or turtle.drop()
              or turtle.dropUp())
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
  while not dropSpotName do
    logger.status("No inventory to drop items into...", colors.orange)
    sleep(3)
    dropSpotName = M.getDropSpotName()
  end

  logger.status("Dropping into \""..dropSpotName.."\"", colors.lightBlue, 0.5)
  while true do
    for i=1,16 do
      if turtle.getItemCount(i) > 0 then
        if not M.dropWaste(i) then
          tracker.select(i)
          turtle.dropUp()
        end
      end
    end
    if M.isInventoryEmpty() then
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
  for i=1,16 do
    if turtle.getItemCount(i) > 0 then
      if not M.useFuelItem(i) then
        M.dropWasteDuringCompression(i)
      end
    end
  end
  defragInventory()
end

function M.isInventoryFull()
  if turtle.getItemCount(16) == 0 then
    return false
  end
  M.compressInventory()
  return turtle.getItemCount(14) > 0
end

return M
