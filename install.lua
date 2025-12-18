---@diagnostic disable: undefined-global, lowercase-global
---@type table
http = http
---@type table
fs = fs
---@type table
shell = shell
---@type table
textutils = textutils

local REPO_BASE = "https://raw.githubusercontent.com/KaeCan/CC-Quarry/refs/heads/main/"

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
  if file then
    file.write(textutils.serialize(defaultConfig))
    file.close()
    print("Created default quarry.config")
    return true
  end
  return false
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
  print("Repository: " .. REPO_BASE)
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
    "tests/integration_test.lua"
  }

  for _, file in ipairs(files) do
    local url = REPO_BASE .. file
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
