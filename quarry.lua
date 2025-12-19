---@diagnostic disable: undefined-global
---@type table
turtle = turtle
---@type table
term = term
---@type table
colors = colors
---@type function
sleep = sleep
---@type table
shell = shell
---@type table
fs = fs
---@type table
textutils = textutils

local version = 3.22

if not turtle then
  print("This program can only be")
  print("  executed by a turtle!")
  return
end

local utils = require("modules.utils")
local logger = require("modules.logger")
local filter = require("modules.item_filter")
local inventory = require("modules.inventory")
local tracker = require("modules.turtle_tracker")
local fuel = require("modules.fuel")
local mining = require("modules.mining")
local persistence = require("modules.persistence")
local configModule = require("modules.config")
local testHooks = require("modules.test_hooks")
local integrationTest = require("tests.integration_test")

if _UD and _UD.su(version, "HqXCPzCg", {...}) then return end

local ARGS = {...}

local config = configModule.load()
configModule.applyArgs(config, ARGS)

local enableTests = false
for _, arg in ipairs(ARGS) do
  if arg == "test" or arg == "--test" then
    enableTests = true
    break
  end
end

if enableTests then
  testHooks.enable()
  integrationTest.setup(config.width, config.length)
  print("Integration tests enabled")
end

local runtimeState = {
  minedBlocks = {},
  holeCount = 0,
  allow = nil,
  ignore = nil
}

local ignoreFile = utils.findFile("ignore.list")
if ignoreFile then
  local ok, list = utils.loadListFile(ignoreFile)
  if ok then
    runtimeState.ignore = {}
    for _,name in pairs(list) do
      runtimeState.ignore[name] = true
    end
    print("Ignoring blocks found in \""..ignoreFile.."\"")
  else
    print("Could not unserialize table from file content: "..ignoreFile)
    return
  end
else
  print("No \"ignore.list\" found in script directory.")
end

local allowFile = utils.findFile("allow.list")
if allowFile then
  local ok, list = utils.loadListFile(allowFile)
  if ok then
    runtimeState.allow = {}
    for _,name in pairs(list) do
      runtimeState.allow[name] = true
    end
    print("Allowing blocks found in \""..allowFile.."\"")
  else
    print("Could not unserialize table from file content: "..allowFile)
    return
  end
else
  print("No \"allow.list\" found in script directory.")
end

-- Initialize Modules
logger.setup({
  enableLogging = config.enableLogging,
  silent = config.silent,
  statusDelay = config.statusDelay,
  version = version
})

logger.log("Quarry initialization: version=" .. tostring(version))
logger.log("Quarry config: width=" .. tostring(config.width) .. " length=" .. tostring(config.length) ..
           " maxDepth=" .. tostring(config.maxDepth) .. " offsetH=" .. tostring(config.offsetH) ..
           " skipHoles=" .. tostring(config.skipHoles) .. " enableLogging=" .. tostring(config.enableLogging))

filter.setup(runtimeState.allow or nil, runtimeState.ignore or nil)
if runtimeState.allow then
  local allowCount = 0
  for _ in pairs(runtimeState.allow) do allowCount = allowCount + 1 end
  logger.log("Filter setup: allow list with " .. tostring(allowCount) .. " items")
end
if runtimeState.ignore then
  local ignoreCount = 0
  for _ in pairs(runtimeState.ignore) do ignoreCount = ignoreCount + 1 end
  logger.log("Filter setup: ignore list with " .. tostring(ignoreCount) .. " items")
end
if not runtimeState.allow and not runtimeState.ignore then
  logger.log("Filter setup: no filters configured (mining all blocks)")
end

inventory.setup(config.fuelSources)

fuel.setup(config.maxDepth)

mining.setup({
  width = config.width,
  length = config.length,
  offsetH = config.offsetH,
  maxDepth = config.maxDepth,
  skipHoles = config.skipHoles,
  rememberBlocks = config.rememberBlocks,
  minedBlocks = runtimeState.minedBlocks,
  holeCount = runtimeState.holeCount
})

term.write("Starting program ")
for i=1,10 do
  term.write(".")
  sleep(1)
end
print(" go")
tracker.select(1)

-- Main Logic
local function main()
  logger.status("Working...", colors.lightBlue)
  logger.log("Main: starting quarry operation")

  local running = true

  local resumedCount = persistence.loadHoleCount()
  local resumed = false
  if resumedCount then
    runtimeState.holeCount = resumedCount
    mining.setHoleCount(resumedCount)
    config.skipHoles = resumedCount
    resumed = true
    logger.log("Main: resuming from hole " .. tostring(runtimeState.holeCount))
    print("Resumed from hole " .. tostring(runtimeState.holeCount))
  else
    logger.log("Main: starting fresh (no resume data found)")
  end

  -- Initial fuel check
  local state = tracker.state
  logger.log("Main: initial fuel check at pos (" .. tostring(state.posx) .. "," .. tostring(state.posy) ..
             ") offsetH=" .. tostring(config.offsetH))
  local fuelCheckCount = 0
  while (not fuel.checkFuel(state.posx, state.posy, config.offsetH, 2, true)) do
    fuelCheckCount = fuelCheckCount + 1
    logger.log("Main: initial fuel check failed, attempt " .. tostring(fuelCheckCount) .. ", waiting")
    sleep(3)
  end
  if fuelCheckCount > 0 then
    logger.log("Main: initial fuel check passed after " .. tostring(fuelCheckCount) .. " attempts")
  end

  if config.offsetH > 0 then
    logger.log("Main: moving down offsetH=" .. tostring(config.offsetH))
    for i=1,config.offsetH do
      tracker.down()
    end
  end

  if not resumed then
    logger.log("Main: calculating fuel needed for layer clearing")
    local layerFuelNeeded = fuel.calculateFuelNeededForLayerClearing(config.width, config.length)
    logger.log("Main: fuel needed for layer clearing: " .. tostring(layerFuelNeeded))
    local layerFuelCheckCount = 0
    while turtle.getFuelLevel() < layerFuelNeeded do
      layerFuelCheckCount = layerFuelCheckCount + 1
      logger.log("Main: insufficient fuel for layer clearing, attempt " .. tostring(layerFuelCheckCount) .. ", waiting")
      sleep(3)
    end
    if layerFuelCheckCount > 0 then
      logger.log("Main: fuel check for layer clearing passed after " .. tostring(layerFuelCheckCount) .. " attempts")
    end

    logger.log("Main: clearing top layer")
    mining.clearLayer()

    logger.log("Main: fuel check after layer clearing")
    local fuelCheckCount = 0
    while (not fuel.checkFuel(state.posx, state.posy, state.depth, 2, true)) do
      fuelCheckCount = fuelCheckCount + 1
      logger.log("Main: fuel check after layer clearing failed, attempt " .. tostring(fuelCheckCount) .. ", waiting")
      sleep(3)
    end
    if fuelCheckCount > 0 then
      logger.log("Main: fuel check after layer clearing passed after " .. tostring(fuelCheckCount) .. " attempts")
    end
  else
    logger.log("Main: skipping layer clearing (resuming from previous session)")
    logger.status("Skipping layer clearing (resuming from previous session)", colors.lime)

    logger.log("Main: fuel check on resume")
    local fuelCheckCount = 0
    while (not fuel.checkFuel(state.posx, state.posy, state.depth, 2, true)) do
      fuelCheckCount = fuelCheckCount + 1
      logger.log("Main: fuel check on resume failed, attempt " .. tostring(fuelCheckCount) .. ", waiting")
      sleep(3)
    end
    if fuelCheckCount > 0 then
      logger.log("Main: fuel check on resume passed after " .. tostring(fuelCheckCount) .. " attempts")
    end
  end

  -- Skip holes if needed
  if (config.skipHoles > 0) then
    logger.log("Main: skipping " .. tostring(config.skipHoles) .. " holes")
    mining.setup({skipHoles = config.skipHoles}) -- Update module config
    local x,y,facing
    local doRun
    x,y,facing, doRun = mining.calculateSkipOffset()
    logger.log("Main: skip offset calculated: pos (" .. tostring(x) .. "," .. tostring(y) ..
               ") facing=" .. tostring(facing) .. " doRun=" .. tostring(doRun))
    logger.status("Skip offset: x="..tostring(x).." y="..tostring(y), colors.lightBlue)
    if doRun then
      logger.log("Main: moving to skip position")
      mining.stepsForward(y-1)
      tracker.turnRight()
      mining.stepsForward(x-1)
      while (state.facing ~= facing) do
        tracker.turnLeft()
      end
      logger.log("Main: arrived at skip position (" .. tostring(state.posx) .. "," .. tostring(state.posy) .. ")")
    end
  end

  local direction = tracker.direction
  logger.log("Main: starting main digging loop")

  while running do
    local lastFacing = state.facing
    logger.log("Main: starting new hole at pos (" .. tostring(state.posx) .. "," .. tostring(state.posy) ..
               ") facing=" .. tostring(state.facing))
    local holeX, holeY, holeDepth = mining.digColumn()
    local nextX, nextY, nextFacing = state.posx, state.posy, state.facing
    logger.log("Main: hole completed, current pos (" .. tostring(nextX) .. "," .. tostring(nextY) ..
               ") facing=" .. tostring(nextFacing))

    if running then
      logger.log("Main: calculating next hole position")
      if state.facing == direction.front then
        if state.posy+5 <= config.length then
          nextY = state.posy + 5
          logger.log("Main: next hole forward 5 spaces to y=" .. tostring(nextY))
        elseif state.posy+3 <= config.length then
          nextX = state.posx + 1
          nextY = state.posy + 3
          nextFacing = direction.back
          logger.log("Main: next hole forward 3 spaces then next row to (" .. tostring(nextX) .. "," .. tostring(nextY) .. ")")
        else
          nextX = state.posx + 1
          nextY = config.length
          nextFacing = direction.back
          logger.log("Main: next hole next row backward to (" .. tostring(nextX) .. "," .. tostring(nextY) .. ")")
        end
      elseif state.facing == direction.back then
        if state.posy-5 >= 1 then
          nextY = state.posy - 5
          logger.log("Main: next hole backward 5 spaces to y=" .. tostring(nextY))
        elseif state.posy-2 >= 1 then
          nextX = state.posx + 1
          nextY = state.posy - 2
          nextFacing = direction.front
          logger.log("Main: next hole backward 2 spaces then next row to (" .. tostring(nextX) .. "," .. tostring(nextY) .. ")")
        else
          nextX = state.posx + 1
          nextY = 1
          nextFacing = direction.front
          logger.log("Main: next hole next row forward to (" .. tostring(nextX) .. "," .. tostring(nextY) .. ")")
        end
      end
      logger.log("Main: next hole target (" .. tostring(nextX) .. "," .. tostring(nextY) ..
                 ") facing=" .. tostring(nextFacing))

      if nextX > config.width then
        logger.log("Main: next hole would exceed width boundary (" .. tostring(nextX) .. " > " .. tostring(config.width) .. "), quarry complete")
        running = false
      end
    end

    logger.log("Main: returning home, continueAfterwards=" .. tostring(running))
    mining.backHome(running, nextX, nextY)

    if not running then
      logger.log("Main: quarry complete, breaking loop")
      break
    end

    logger.log("Main: turning to face next hole direction " .. tostring(nextFacing))
    while state.facing ~= nextFacing do
      tracker.turnLeft()
    end
    logger.log("Main: ready for next hole")
  end

  logger.log("Main: quarry operation complete, total holes dug: " .. tostring(mining.getHoleCount()))
  logger.status("Finished quarry. Returning home...", colors.lime)
  mining.backHome(false)

  if enableTests then
    local expectedHoles = integrationTest.calculateExpectedHoles(config.width, config.length)
    logger.log("Main: running integration tests, expected holes: " .. tostring(expectedHoles))
    testHooks.onQuarryComplete(expectedHoles)
    integrationTest.printResults()
  end

  logger.log("Main: quarry operation finished")
  logger.status("Done.", colors.lightBlue)
end

main()
