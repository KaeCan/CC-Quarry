---@diagnostic disable: undefined-global, lowercase-global
---@type table
http = http
---@type table
fs = fs
---@type table
shell = shell
---@type table
textutils = textutils

local REPO_OWNER = "KaeCan"
local REPO_NAME = "CC-Quarry"
local REPO_BRANCH = "main"
local GITHUB_API_BASE = "https://api.github.com/repos/" .. REPO_OWNER .. "/" .. REPO_NAME
local GITHUB_RAW_BASE = "https://raw.githubusercontent.com/" .. REPO_OWNER .. "/" .. REPO_NAME

local function printUsage()
  print("Usage: install [target_folder]")
  print("  target_folder: Where to install/update the quarry (default: current directory)")
  print()
  print("Example: install quarry")
  print("  This will install/update in ./quarry/")
end

local function ensureDir(path)
  if not fs.exists(path) then
    fs.makeDir(path)
  end
end

local function getLatestCommitHash()
  print("Fetching latest commit hash...")
  local apiUrl = GITHUB_API_BASE .. "/commits/" .. REPO_BRANCH

  local response = http.get(apiUrl)
  if not response then
    return nil, "Failed to fetch commit hash from GitHub API"
  end

  local content = response.readAll()
  response.close()

  local shaMatch = content:match('"sha"%s*:%s*"([a-f0-9]+)"')
  if shaMatch then
    return shaMatch
  end

  return nil, "Could not parse commit hash from API response"
end

local function downloadFile(url, filepath)
  print("Downloading " .. filepath .. "...")

  local response = http.get(url)
  if not response then
    return false, "Failed to download: " .. url
  end

  local content = response.readAll()
  response.close()

  local file = fs.open(filepath, "w")
  if not file then
    return false, "Failed to open file for writing: " .. filepath
  end

  file.write(content)
  file.close()
  return true
end

local function fileExists(filepath)
  return fs.exists(filepath) and not fs.isDir(filepath)
end

local function createDefaultConfig(configPath)
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

  local file = fs.open(configPath, "w")
  if not file then
    return false
  end

  local keyOrder = {
    "width", "length", "offsetH", "maxDepth", "skipHoles",
    "fuelSources", "enableLogging", "silent", "statusDelay", "rememberBlocks"
  }

  file.write("{\n")
  for i, key in ipairs(keyOrder) do
    local value = defaultConfig[key]
    local valueStr
    if value == nil then
      valueStr = "nil"
    elseif type(value) == "string" then
      valueStr = "\"" .. value .. "\""
    elseif type(value) == "boolean" then
      valueStr = tostring(value)
    elseif type(value) == "number" then
      valueStr = tostring(value)
    elseif type(value) == "table" then
      valueStr = textutils.serialize(value)
    else
      valueStr = tostring(value)
    end

    file.write("  " .. key .. " = " .. valueStr)
    if i < #keyOrder then
      file.write(",\n")
    else
      file.write("\n")
    end
  end
  file.write("}")

  file.close()
  print("Created default quarry.config")
  return true
end

local function createDefaultAllowList(listPath)
  if fileExists(listPath) then
    return false
  end

  local defaultAllow = textutils.serialize({})
  local file = fs.open(listPath, "w")
  if file then
    file.write(defaultAllow)
    file.close()
    print("Created default allow.list")
    return true
  end
  return false
end

local function createDefaultIgnoreList(listPath)
  if fileExists(listPath) then
    return false
  end

  local defaultIgnore = textutils.serialize({
    "tag@forge:dirt",
    "tag@forge:stone",
    "tag@forge:cobblestone",
    "minecraft:cobblestone",
    "minecraft:stone",
    "minecraft:dirt",
    "minecraft:gravel"
  })

  local file = fs.open(listPath, "w")
  if file then
    file.write(defaultIgnore)
    file.close()
    print("Created default ignore.list")
    return true
  end
  return false
end

local function install(targetDir)
  if not targetDir or targetDir == "" then
    targetDir = shell and shell.dir() or "."
  elseif shell then
    if targetDir:sub(1, 1) ~= "/" then
      targetDir = shell.dir() .. "/" .. targetDir
    end
  end

  if not fs.exists(targetDir) then
    print("Creating directory: " .. targetDir)
    fs.makeDir(targetDir)
  end

  if not fs.isDir(targetDir) then
    print("Error: " .. targetDir .. " is not a directory")
    return
  end

  if not targetDir:match("/$") then
    targetDir = targetDir .. "/"
  end

  print("Installing/updating quarry in: " .. targetDir)
  print("Repository: " .. REPO_OWNER .. "/" .. REPO_NAME .. " (" .. REPO_BRANCH .. ")")
  print()

  local commitHash, err = getLatestCommitHash()
  if not commitHash then
    print("Error: " .. err)
    print("Falling back to branch-based URL (may be cached)")
    commitHash = REPO_BRANCH
  else
    print("Using commit: " .. commitHash:sub(1, 7) .. "...")
  end
  print()

  ensureDir(targetDir .. "modules")
  ensureDir(targetDir .. "tests")

  local files = {
    "quarry.lua",
    "item_evaluator.lua",
    "block_tag_logger.lua",
    "item_tag_logger.lua",
    "run_tests.lua",
    "modules/utils.lua",
    "modules/logger.lua",
    "modules/item_filter.lua",
    "modules/turtle_tracker.lua",
    "modules/inventory.lua",
    "modules/fuel.lua",
    "modules/persistence.lua",
    "modules/mining.lua",
    "modules/config.lua",
    "modules/test_hooks.lua",
    "tests/framework.lua",
    "tests/mocks.lua",
    "tests/test_utils.lua",
    "tests/test_item_filter.lua",
    "tests/test_fuel.lua",
    "tests/test_inventory.lua",
    "tests/test_tracker.lua",
    "tests/test_mining.lua",
    "tests/integration_test.lua"
  }

  for _, file in ipairs(files) do
    local url = GITHUB_RAW_BASE .. "/" .. commitHash .. "/" .. file
    local filepath = targetDir .. file
    local ok, err = downloadFile(url, filepath)
    if not ok then
      print("Error: " .. err)
      return
    end
  end

  local allowListPath = targetDir .. "allow.list"
  local ignoreListPath = targetDir .. "ignore.list"
  local configPath = targetDir .. "quarry.config"

  local allowExists = fileExists(allowListPath)
  local ignoreExists = fileExists(ignoreListPath)

  if not allowExists and not ignoreExists then
    createDefaultAllowList(allowListPath)
    createDefaultIgnoreList(ignoreListPath)
  else
    if allowExists then
      print("Preserving existing allow.list")
    end
    if ignoreExists then
      print("Preserving existing ignore.list")
    end
  end

  if not fileExists(configPath) then
    createDefaultConfig(configPath)
  else
    print("Preserving existing quarry.config")
  end

  print()
  print("Installation complete!")
  print("Run: " .. targetDir .. "quarry")
end

local args = {...}
if args[1] == "help" or args[1] == "-h" or args[1] == "--help" then
  printUsage()
else
  install(args[1])
end
