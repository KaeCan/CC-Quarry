---@diagnostic disable: undefined-global
---@type table
fs = fs
---@type table
shell = shell

local M = {}

function M.saveMinedBlocks(rememberBlocks, minedBlocks)
  if not rememberBlocks then
    return
  end
  local f = fs.open("mined-blocks.txt","w")
  if f then
    for name,_ in pairs(minedBlocks) do
      f.write(name.."\n")
    end
    f.close()
  end
end

function M.saveHoleCount(holeCount)
  local logFile = nil
  if shell then
    local scriptPath = shell.getRunningProgram()
    if scriptPath then
      local scriptDir = scriptPath:match("^(.+)/[^/]+$")
      if scriptDir then
        logFile = scriptDir .. "/lastHole.log"
      else
        logFile = "/lastHole.log"
      end
    else
      logFile = "lastHole.log"
    end
  else
    logFile = "lastHole.log"
  end

  local f = fs.open(logFile, "w")
  if f then
    f.write(tostring(holeCount))
    f.close()
  end
end

function M.loadHoleCount()
  local logFile = nil
  if shell then
    local scriptPath = shell.getRunningProgram()
    if scriptPath then
      local scriptDir = scriptPath:match("^(.+)/[^/]+$")
      if scriptDir then
        logFile = scriptDir .. "/lastHole.log"
      else
        logFile = "/lastHole.log"
      end
    else
      logFile = "lastHole.log"
    end
  else
    logFile = "lastHole.log"
  end

  if fs.exists(logFile) and not fs.isDir(logFile) then
    local f = fs.open(logFile, "r")
    if f then
      local content = f.readAll()
      f.close()
      local count = tonumber(content)
      if count then
        return count
      end
    end
  end
  return nil
end

return M
