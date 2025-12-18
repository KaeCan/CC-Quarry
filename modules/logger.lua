---@diagnostic disable: undefined-global
---@type table
colors = colors
---@type table
fs = fs
---@type table
os = os
---@type table
term = term
---@type function
sleep = sleep

local utils = require("modules.utils")
local M = {}

local config = {
  enableLogging = false,
  silent = false,
  statusDelay = false,
  version = 3.22
}

local directionNames = {[0]="front", [1]="right", [2]="back", [3]="left"}

function M.setup(conf)
  for k,v in pairs(conf) do
    config[k] = v
  end
end

function M.log(text)
  if not config.enableLogging then
    return
  end
  local logFile = utils.getScriptPath("quarry.log")
  local f = fs.open(logFile, "a")
  if f then
    f.write(tostring(os.date()).."\n")
    f.write(text.."\n")
    f.close()
  end
end

function M.status(text, color, delay)
  if config.silent then
    return
  end
  M.log(text)
  term.clear()
  term.setCursorPos(1,1)
  if term.isColor() then
    term.setTextColor(colors.yellow)
  end
  print(" Turtle-Quarry "..tostring(config.version))
  print("--------------------")
  print()
  if term.isColor() then
    term.setTextColor(colors.white)
  end
  term.write("--> ")
  if term.isColor() then
    if color == nil then
      color = colors.white
    end
    term.setTextColor(color)
  end
  print(text)
  if term.isColor() and color ~= colors.white then
    term.setTextColor(colors.white)
  end
  if delay and config.statusDelay then
    sleep(delay)
  end
end

function M.logPosition(context, state)
  if not config.enableLogging then
    return
  end
  local facingStr = directionNames[state.facing] or "unknown"

  local posInfo = string.format("LayerClear: %s | Pos: x=%d y=%d depth=%d facing=%s",
    context or "move", state.posx, state.posy, state.depth, facingStr)
  M.log(posInfo)
end

return M
