---@diagnostic disable: undefined-global
---@type table
fs = fs
---@type table
shell = shell
---@type table
textutils = textutils

local utils = require("modules.utils")

local M = {}

local defaultConfig = {
  width = 16,
  length = 16,
  offsetH = 0,
  maxDepth = 130,
  skipHoles = 0,
  fuelSources = nil,
  enableLogging = false,
  silent = false,
  statusDelay = false,
  rememberBlocks = false
}

function M.getConfigFile()
  return utils.getScriptPath("quarry.config")
end

function M.load()
  local configFile = M.getConfigFile()
  local config = {}

  for k, v in pairs(defaultConfig) do
    config[k] = v
  end

  if fs.exists(configFile) and not fs.isDir(configFile) then
    local file = fs.open(configFile, "r")
    if file then
      local content = file.readAll()
      file.close()
      local ok, savedConfig = pcall(textutils.unserialize, content)
      if ok and savedConfig and type(savedConfig) == "table" then
        for k, v in pairs(savedConfig) do
          if defaultConfig[k] ~= nil then
            config[k] = v
          end
        end
      end
    end
  end

  return config
end

function M.save(config)
  local configFile = M.getConfigFile()
  local file = fs.open(configFile, "w")
  if file then
    local serialized = textutils.serialize(config)
    file.write(serialized)
    file.close()
    return true
  end
  return false
end

function M.applyArgs(config, args)
  for _, par in pairs(args) do
    if utils.startswith(par, "w:") then
      config.width = tonumber(string.sub(par, string.len("w:")+1))
      print("Quarry width: "..tostring(config.width))

    elseif utils.startswith(par, "l:") then
      config.length = tonumber(string.sub(par, string.len("l:")+1))
      print("Quarry length: "..tostring(config.length))

    elseif utils.startswith(par, "offh:") then
      config.offsetH = tonumber(string.sub(par, string.len("offh:")+1))
      print("Quarry height offset: "..tostring(config.offsetH))

    elseif utils.startswith(par, "maxd:") then
      config.maxDepth = tonumber(string.sub(par, string.len("maxd:")+1))
      print("Quarry maximum depth: "..tostring(config.maxDepth))

    elseif utils.startswith(par, "skip:") then
      config.skipHoles = tonumber(string.sub(par, string.len("skip:")+1))
      print("Skipping the first "..tostring(config.skipHoles).." holes")

    elseif par == "burnfuel" then
      config.fuelSources = {["minecraft:coal"] = true}
      print("Fuel item usage activated")

    elseif par == "enable-logging" then
      config.enableLogging = true
      print("Logging enabled")

    elseif par == "remember-blocks" then
      config.rememberBlocks = true
      print("Remember blocks enabled")

    elseif par == "silent" then
      config.silent = true
      print("Disabled status information")

    elseif par == "statusdelay" then
      config.statusDelay = true
      print("Enabled status delay")
    end
  end
end

return M
