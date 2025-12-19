---@diagnostic disable: undefined-global
---@type table
fs = fs
---@type table
shell = shell

local utils = require("modules.utils")
local logger = require("modules.logger")
local M = {}

function M.saveMinedBlocks(rememberBlocks, minedBlocks)
  if not rememberBlocks then
    return
  end
  local logFile = utils.getScriptPath("mined_blocks.log")
  local blockCount = 0
  for _ in pairs(minedBlocks) do blockCount = blockCount + 1 end
  logger.log("saveMinedBlocks: saving " .. tostring(blockCount) .. " unique blocks to " .. logFile)
  local f = fs.open(logFile, "w")
  if f then
    for name,_ in pairs(minedBlocks) do
      f.write(name.."\n")
    end
    f.close()
    logger.log("saveMinedBlocks: saved successfully")
  else
    logger.log("saveMinedBlocks: failed to open file for writing")
  end
end

function M.saveHoleCount(holeCount)
  local logFile = utils.getScriptPath("last_hole.log")
  logger.log("saveHoleCount: saving holeCount=" .. tostring(holeCount) .. " to " .. logFile)
  local f = fs.open(logFile, "w")
  if f then
    f.write(tostring(holeCount))
    f.close()
    logger.log("saveHoleCount: saved successfully")
  else
    logger.log("saveHoleCount: failed to open file for writing")
  end
end

function M.loadHoleCount()
  local logFile = utils.getScriptPath("last_hole.log")
  logger.log("loadHoleCount: checking for file " .. logFile)
  if fs.exists(logFile) and not fs.isDir(logFile) then
    local f = fs.open(logFile, "r")
    if f then
      local content = f.readAll()
      f.close()
      local count = tonumber(content)
      if count then
        logger.log("loadHoleCount: loaded holeCount=" .. tostring(count))
        return count
      else
        logger.log("loadHoleCount: file exists but content is not a valid number: " .. tostring(content))
      end
    else
      logger.log("loadHoleCount: file exists but could not be opened")
    end
  else
    logger.log("loadHoleCount: file does not exist")
  end
  return nil
end

return M
