---@diagnostic disable: undefined-global
---@type table
turtle = turtle
---@type table
colors = colors
---@type function
sleep = sleep

local tracker = require("modules.turtle_tracker")
local inventory = require("modules.inventory")
local fuel = require("modules.fuel")
local logger = require("modules.logger")
local filter = require("modules.item_filter")
local persistence = require("modules.persistence")
local testHooks = require("modules.test_hooks")

local M = {}

local config = {
  width = 16,
  length = 16,
  offsetH = 0,
  maxDepth = 130,
  skipHoles = 0,
  rememberBlocks = false,
  minedBlocks = {},
  holeCount = 0
}

function M.setup(conf)
  for k,v in pairs(conf) do
    config[k] = v
  end
end

function M.setHoleCount(count)
  config.holeCount = count
end

function M.getHoleCount()
  return config.holeCount
end

-- Makes the turtle return to the starting position and empty its inventory
-- If continueAfterwards is true, calculates fuel needs and waits/refuels
function M.backHome(continueAfterwards, targetX, targetY)
  local state = tracker.state
  local lastDepth = state.depth
  local lastFacing = state.facing
  local lastX = state.posx
  local lastY = state.posy

  while state.depth > 0 do
    tracker.up()
    state.depth = state.depth - 1
  end

  -- go home in x-direction
  if lastX > 1 then
    while state.facing ~= tracker.direction.left do
      tracker.turnLeft()
    end
    while state.posx > 1 do
      tracker.forward()
    end
  end

  while state.facing ~= tracker.direction.back do
    tracker.turnLeft()
  end
  while state.posy > 1 do
    tracker.forward()
  end

  -- go up the offset
  if config.offsetH > 0 then
    for i=1,config.offsetH do
      tracker.up()
    end
  end

  inventory.compressInventory()

  if inventory.fuelSources then
    logger.status("Trying to use fuel...", colors.lightBlue)
    for i=1,16 do
      inventory.useFuelItem(i)
    end
  end

  -- drop desired items into chest
  local isEmpty = inventory.isInventoryEmpty()
  if (not isEmpty) then
    inventory.dropItemsInChest()
    isEmpty = inventory.isInventoryEmpty()
  end

  persistence.saveMinedBlocks(config.rememberBlocks, config.minedBlocks)

  testHooks.onBackHome(continueAfterwards, targetX, targetY)

  if continueAfterwards then
    local nextX = targetX or lastX
    local nextY = targetY or lastY
    local fuelNeeded = fuel.calculateFuelNeeded(nextX, nextY)

    while turtle.getFuelLevel() < fuelNeeded or (not isEmpty) do
      if turtle.getFuelLevel() < fuelNeeded then
        logger.status("Need "..tostring(fuelNeeded).." fuel, have "..tostring(turtle.getFuelLevel())..". Waiting...", colors.orange)
        testHooks.onFuelWait(fuelNeeded, turtle.getFuelLevel())
      end
      if not isEmpty then
        logger.status("Inventory not empty, trying to deposit...", colors.orange)
        inventory.compressInventory()
        if not inventory.isInventoryEmpty() then
          inventory.dropItemsInChest()
        end
        isEmpty = inventory.isInventoryEmpty()
      end
      sleep(3)
    end

    logger.status("Fuel check passed. Continuing work...", colors.lime)

    if config.offsetH > 0 then
      for i=1,config.offsetH do
        tracker.down()
      end
    end

    -- back to hole in y-direction
    while state.facing ~= tracker.direction.front do
      tracker.turnLeft()
    end
    while state.posy < nextY do
      tracker.forward()
    end

    if nextX > 1 then
      while state.facing ~= tracker.direction.right do
        tracker.turnRight()
      end
      while state.posx < nextX do
        tracker.forward()
      end
    end

    while state.facing ~= lastFacing do
      tracker.turnLeft()
    end
  end
end

local function digSides()
  local inspectBlocks = filter.hasFilters()

  for i=1,4 do
    local digIt = turtle.detect()
    if digIt then
      if inspectBlocks then
        local success, data = turtle.inspect()
        if success then
          digIt = filter.isDesired(data, data)
          if digIt and config.rememberBlocks then
            config.minedBlocks[data.name] = true
          end
        else
          digIt = false  -- If inspection fails, don't dig
        end
      end
      -- If inspectBlocks is false, digIt remains true (dig everything)
    end
    if digIt then
      tracker.select(1)
      turtle.dig()
      if inventory.isInventoryFull() then
        M.backHome(true)
      end
    end
    tracker.turnLeft()
  end
end

local function drill()
  if turtle.detectDown() then
    tracker.select(1)
    turtle.digDown()
    if inventory.isInventoryFull() then
      M.backHome(true)
    end
  end
end

function M.digColumn()
  local state = tracker.state
  drill()
  while true do
    if not fuel.checkFuel(state.posx, state.posy, state.depth, 1, false) then
      M.backHome(true)
    end

    if not turtle.down() then
      drill()
      if not turtle.down() then
        break
      end
    end
    state.depth = state.depth + 1
    if inventory.isInventoryFull() then
      M.backHome(true)
    end
    digSides()

    if (config.maxDepth > 0) and (state.depth >= config.maxDepth) then
      break;
    end

    drill()
  end

  while state.depth > 0 do
    tracker.up()
    state.depth = state.depth - 1
  end

  config.holeCount = config.holeCount + 1
  persistence.saveHoleCount(config.holeCount)

  logger.status("Hole "..tostring(config.holeCount).." at x:"..tostring(state.posx).." y:"..tostring(state.posy).." is done.", colors.lightBlue)

  testHooks.onHoleComplete(state.posx, state.posy, config.holeCount)

  return state.posx, state.posy, 0
end

function M.stepsForward(count)
  local state = tracker.state
  if (count > 0) then
    for i=1,count do
      if not fuel.checkFuel(state.posx, state.posy, state.depth, 1, false)
          or inventory.isInventoryFull() then
        M.backHome(true)
      end
      tracker.forward()
    end
  end
end

function M.calculateSkipOffset()
  local running = true
  local facing = tracker.direction.front
  local x = 1
  local y = 1
  local skips = config.skipHoles

  while running do
    skips = skips - 1

    -- check for finish condition
    if (x == config.width) then
      if ((facing == tracker.direction.front) and ((y + 5) > config.length))
          or ((facing == tracker.direction.back) and ((y-5) < 1)) then
        running = false
      end
    end

    if running then
      if facing == tracker.direction.front then
        if y+5 <= config.length then
          y = y+5
        elseif y+3 <= config.length then
          y = y+3
          x = x+1
          facing = tracker.direction.back
        else
          x = x+1
          facing = tracker.direction.back
          y = y-2
        end
      elseif facing == tracker.direction.back then
        if y-5 >= 1 then
          y = y-5
        elseif y-2 >= 1 then
          y = y-2
          x = x+1
          facing = tracker.direction.front
        else
          x = x+1
          facing = tracker.direction.front
          y = y+3
        end
      end
    end

    if (skips <= 0) then
      break
    end
  end

  return x,y,facing,running
end

function M.clearLayer()
  logger.status("Clearing top layer...", colors.lightBlue)
  local state = tracker.state
  local direction = tracker.direction

  while state.posx > 1 do
    while state.facing ~= direction.left do
      tracker.turnLeft()
    end
    tracker.forward()
    logger.logPosition("navigate-to-start-x", state)
  end

  while state.posy > 1 do
    while state.facing ~= direction.back do
      tracker.turnLeft()
    end
    tracker.forward()
    logger.logPosition("navigate-to-start-y", state)
  end

  while state.facing ~= direction.front do
    tracker.turnLeft()
  end

  for x = 1, config.width do
    local goingForward = (x % 2 == 1)
    local startY = goingForward and 1 or config.length

    if x == 1 then
    elseif goingForward then
      while state.facing ~= direction.front do
        tracker.turnLeft()
      end
    else
      while state.facing ~= direction.back do
        tracker.turnLeft()
      end
    end

    local y = startY

    if not fuel.checkFuel(state.posx, state.posy, state.depth, 1, false) then
      local saveX, saveY = state.posx, state.posy
      M.backHome(true, saveX, saveY)
      if goingForward then
        while state.facing ~= direction.front do tracker.turnLeft() end
      else
        while state.facing ~= direction.back do tracker.turnLeft() end
      end
    end

    if turtle.detect() then tracker.select(1); turtle.dig() end
    if turtle.detectDown() then tracker.select(1); turtle.digDown() end
    logger.logPosition(string.format("row-%d-col-%d", x, y), state)

    while true do
       if not fuel.checkFuel(state.posx, state.posy, state.depth, 1, false) then
         local saveX, saveY = state.posx, state.posy
         M.backHome(true, saveX, saveY)
         if goingForward then
            while state.facing ~= direction.front do tracker.turnLeft() end
         else
            while state.facing ~= direction.back do tracker.turnLeft() end
         end
       end

       if goingForward then
         if y >= config.length then break end
       else
         if y <= 1 then break end
       end

       tracker.forward()
       if goingForward then y = y + 1 else y = y - 1 end

       if turtle.detect() then tracker.select(1); turtle.dig() end
       if turtle.detectDown() then tracker.select(1); turtle.digDown() end

       if inventory.isInventoryFull() then
         inventory.compressInventory()
         if inventory.isInventoryFull() then
            local saveX, saveY = state.posx, state.posy
            M.backHome(true, saveX, saveY)
            if goingForward then
                while state.facing ~= direction.front do tracker.turnLeft() end
            else
                while state.facing ~= direction.back do tracker.turnLeft() end
            end
         end
       end
       logger.logPosition(string.format("row-%d-col-%d", x, y), state)
    end

    if x < config.width then
      if goingForward then
        tracker.turnRight()
        tracker.forward()
        logger.logPosition(string.format("transition-row-%d-to-%d", x, x+1), state)
        tracker.turnRight()
      else
        tracker.turnLeft()
        tracker.forward()
        logger.logPosition(string.format("transition-row-%d-to-%d", x, x+1), state)
        tracker.turnLeft()
      end
    end
  end

  while state.posx > 1 do
    while state.facing ~= direction.left do tracker.turnLeft() end
    tracker.forward()
    logger.logPosition("return-to-home-x", state)
  end
  while state.posy > 1 do
    while state.facing ~= direction.back do tracker.turnLeft() end
    tracker.forward()
    logger.logPosition("return-to-home-y", state)
  end
  while state.facing ~= direction.front do tracker.turnLeft() end

  logger.status("Layer cleared.", colors.lime)
  inventory.compressInventory()

  if not inventory.isInventoryEmpty() then
    if config.offsetH > 0 then
      for i=1,config.offsetH do tracker.up() end
    end
    inventory.compressInventory()

    if inventory.fuelSources then
        logger.status("Trying to use fuel...", colors.lightBlue)
        for i=1,16 do inventory.useFuelItem(i) end
    end

    inventory.dropItemsInChest()

    local fuelNeeded = fuel.calculateFuelNeeded(1, 1)
    while turtle.getFuelLevel() < fuelNeeded do
       logger.status("Need "..tostring(fuelNeeded).." fuel, have "..tostring(turtle.getFuelLevel())..". Waiting...", colors.orange)
       testHooks.onFuelWait(fuelNeeded, turtle.getFuelLevel())
       sleep(3)
    end

    if config.offsetH > 0 then
      for i=1,config.offsetH do tracker.down() end
    end
  end
end

return M
