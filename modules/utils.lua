---@diagnostic disable: undefined-global
---@type table
shell = shell
---@type table
fs = fs
---@type table
textutils = textutils

local M = {}

function M.startswith(text, piece)
  return string.sub(text, 1, string.len(piece)) == piece
end

function M.isTableEmpty(tbl)
  for k,v in pairs(tbl) do
    return false
  end
  return true
end

function M.getScriptDir()
  if shell then
    local scriptPath = shell.getRunningProgram()
    if scriptPath then
      local scriptDir = scriptPath:match("^(.+)/[^/]+$")
      if scriptDir then
        return scriptDir
      else
        return "/"
      end
    end
  end
  return nil
end

function M.getScriptPath(filename)
  local scriptDir = M.getScriptDir()
  if scriptDir then
    return scriptDir .. "/" .. filename
  else
    return filename
  end
end

function M.findFile(filename)
  local filepath = M.getScriptPath(filename)
  if fs.exists(filepath) and not fs.isDir(filepath) then
    return filepath
  end
  return nil
end

function M.loadListFile(filepath)
  if not filepath then
    return false, nil
  end

  local file = fs.open(filepath, "r")
  if not file then
    return false, nil
  end

  local ok, list = pcall(textutils.unserialize, file.readAll())
  file.close()

  if not ok or not list then
    return false, nil
  end

  return true, list
end

return M
