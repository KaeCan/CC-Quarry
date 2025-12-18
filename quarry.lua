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

filter.setup(runtimeState.allow or nil, runtimeState.ignore or nil)

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

  local running = true

  local resumedCount = persistence.loadHoleCount()
  local resumed = false
  if resumedCount then
    runtimeState.holeCount = resumedCount
    mining.setHoleCount(resumedCount)
    config.skipHoles = resumedCount
    resumed = true
    print("Resumed from hole " .. tostring(runtimeState.holeCount))
  end

  -- Initial fuel check
  local state = tracker.state
  while (not fuel.checkFuel(state.posx, state.posy, config.offsetH, 2, true)) do
    sleep(3)
  end

  if config.offsetH > 0 then
    for i=1,config.offsetH do
      tracker.down()
    end
  end

  if not resumed then
    mining.clearLayer()
  else
    logger.status("Skipping layer clearing (resuming from previous session)", colors.lime)
  end

  -- Skip holes if needed
  if (config.skipHoles > 0) then
    mining.setup({skipHoles = config.skipHoles}) -- Update module config
    local x,y,facing
    local doRun
    x,y,facing, doRun = mining.calculateSkipOffset()
    logger.status("Skip offset: x="..tostring(x).." y="..tostring(y), colors.lightBlue)
    if doRun then
      mining.stepsForward(y-1)
      tracker.turnRight()
      mining.stepsForward(x-1)
      while (state.facing ~= facing) do
        tracker.turnLeft()
      end
    end
  end

  local direction = tracker.direction

  while running do
    local lastFacing = state.facing
    local holeX, holeY, holeDepth = mining.digColumn()
    local nextX, nextY, nextFacing = state.posx, state.posy, state.facing

    if (state.posx == config.width) then
      if ((state.facing == direction.front) and ((state.posy + 5) > config.length))
          or ((state.facing == direction.back) and ((state.posy-5) < 1)) then
        running = false
      end
    end

    if running then
      if state.facing == direction.front then
        if state.posy+5 <= config.length then
          nextY = state.posy + 5
        elseif state.posy+3 <= config.length then
          nextX = state.posx + 1
          nextY = state.posy + 3
          nextFacing = direction.back
        else
          nextX = state.posx + 1
          nextY = state.posy - 2
          nextFacing = direction.back
        end
      elseif state.facing == direction.back then
        if state.posy-5 >= 1 then
          nextY = state.posy - 5
        elseif state.posy-2 >= 1 then
          nextX = state.posx + 1
          nextY = state.posy - 2
          nextFacing = direction.front
        else
          nextX = state.posx + 1
          nextY = state.posy + 3
          nextFacing = direction.front
        end
      end
    end

    mining.backHome(running, nextX, nextY)

    if not running then
      break
    end

    while state.facing ~= nextFacing do
      tracker.turnLeft()
    end
  end

  logger.status("Finished quarry. Returning home...", colors.lime)
  mining.backHome(false)

  if enableTests then
    local expectedHoles = integrationTest.calculateExpectedHoles(config.width, config.length)
    testHooks.onQuarryComplete(expectedHoles)
    integrationTest.printResults()
  end

  logger.status("Done.", colors.lightBlue)
end

main()
