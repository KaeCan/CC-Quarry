---@diagnostic disable: undefined-global
---@type table
peripheral = peripheral

local utils = require("modules.utils")
local M = {}

local lists = {
  allow = nil,
  ignore = nil
}

function M.setup(allowList, ignoreList)
  lists.allow = allowList
  lists.ignore = ignoreList
  -- Note: logger may not be available here, so we'll log from quarry.lua instead
end

function M.getTags(data)
  if not data then
    return nil
  end

  if data.tags then
    return data.tags
  elseif data.tag then
    return data.tag
  end

  if peripheral then
    local tagPeripheral = peripheral.find("oreDictionary")
    if tagPeripheral then
      if tagPeripheral.getItemTags then
        local ok, tags = pcall(tagPeripheral.getItemTags, data.name)
        if ok and tags then
          return tags
        end
      end
      if tagPeripheral.getBlockTags then
        local ok, tags = pcall(tagPeripheral.getBlockTags, data.name)
        if ok and tags then
          return tags
        end
      end
    end
  end

  return nil
end

function M.checkTagInList(tag, list)
  if not tag or not list then
    return false
  end

  local tagStr = tostring(tag)

  for entry, _ in pairs(list) do
    -- Check for both "tag@" and "tags@" prefixes
    if utils.startswith(entry, "tag@") or utils.startswith(entry, "tags@") then
      local prefixLen = utils.startswith(entry, "tags@") and string.len("tags@") or string.len("tag@")
      local tagName = string.sub(entry, prefixLen + 1)
      -- Check exact match first, then substring match
      if tagStr == tagName or tagStr:find(tagName, 1, true) then
        return true
      end
    end
  end

  return false
end

function M.isAllowed(itemName, data)
  if lists.allow[itemName] == true then
    return true
  end

  if data then
    local tags = M.getTags(data)
    if tags then
      -- Handle tags as table or single value
      if type(tags) == "table" then
        -- Check both array-style and hash-style tables
        for k, v in pairs(tags) do
          local tag = type(k) == "number" and v or k
          if M.checkTagInList(tostring(tag), lists.allow) then
            return true
          end
        end
      else
        if M.checkTagInList(tostring(tags), lists.allow) then
          return true
        end
      end
    end
  end

  return false
end

function M.isNotIgnored(itemName, data)
  if lists.ignore[itemName] == true then
    return false
  end

  if data then
    local tags = M.getTags(data)
    if tags then
      -- Handle tags as table or single value
      if type(tags) == "table" then
        -- Check both array-style and hash-style tables
        for k, v in pairs(tags) do
          local tag = type(k) == "number" and v or k
          if M.checkTagInList(tostring(tag), lists.ignore) then
            return false
          end
        end
      else
        if M.checkTagInList(tostring(tags), lists.ignore) then
          return false
        end
      end
    end
  end

  return true
end

function M.alwaysTrue()
  return true
end

-- Check if filtering is active (either allow or ignore list exists)
function M.hasFilters()
  return (lists.allow ~= nil) or (lists.ignore ~= nil)
end

-- checks if a given item name is of interest for the quarry
-- allow list overrules ignore list when both are present
-- itemNameOrData: can be a string (item name) or a table (block data with .name field)
function M.isDesired(itemNameOrData, blockData)
  local itemName = type(itemNameOrData) == "string" and itemNameOrData or itemNameOrData.name
  local data = blockData or (type(itemNameOrData) == "table" and itemNameOrData or nil)

  if lists.allow then
    return M.isAllowed(itemName, data)
  elseif lists.ignore then
    return M.isNotIgnored(itemName, data)
  else
    return M.alwaysTrue()
  end
end

return M
