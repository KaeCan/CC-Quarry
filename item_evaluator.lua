-- Item Evaluator
-- Evaluates whether the first item in inventory will be allowed or ignored by the quarry

if not turtle then
  print("This program can only be executed by a turtle!")
  return
end

local utils = require("modules.utils")
local filter = require("modules.item_filter")

-- Read ignore file
local ignore = nil
local ignoreFile = utils.findFile("ignore.list")
if ignoreFile then
  local ok, list = utils.loadListFile(ignoreFile)
  if ok then
    ignore = {}
    for _,name in pairs(list) do
      ignore[name] = true
    end
    print("Loaded ignore list from \""..ignoreFile.."\"")
  else
    print("Could not unserialize table from file content: "..ignoreFile)
  end
else
  -- Debug info about missing file (simplified from original)
  print("No \"ignore.list\" found in script directory")
end

-- Read allow file
local allow = nil
local allowFile = utils.findFile("allow.list")
if allowFile then
  local ok, list = utils.loadListFile(allowFile)
  if ok then
    allow = {}
    for _,name in pairs(list) do
      allow[name] = true
    end
    print("Loaded allow list from \""..allowFile.."\"")
  else
    print("Could not unserialize table from file content: "..allowFile)
  end
else
  print("No \"allow.list\" found in script directory")
end

-- Setup filter module
filter.setup(allow, ignore)

print()
print("Item Evaluator")
print("==============")
print()

-- Check first inventory slot
if turtle.getItemCount(1) == 0 then
  print("No item found in slot 1!")
  print("Please place an item in slot 1 and run again.")
  return
end

local itemData = turtle.getItemDetail(1)
local itemName = itemData.name

print("Item: " .. tostring(itemName))
print("Slot: 1")
print("Count: " .. tostring(itemData.count))
if itemData.damage and itemData.damage ~= 0 then
  print("Damage: " .. tostring(itemData.damage))
end
print()

-- Get item tags for display
local itemTags = filter.getTags(itemData)
if itemTags then
  print("Item Tags:")
  if type(itemTags) == "table" then
    for k, v in pairs(itemTags) do
      local tag = type(k) == "number" and v or k
      print("  - " .. tostring(tag))
    end
  else
    print("  - " .. tostring(itemTags))
  end
  print()
end

-- Evaluate item
local desired = filter.isDesired(itemName, itemData)

print("Evaluation:")
print("----------")

if not allow and not ignore then
  print("Status: ALLOWED (no allow/ignore lists configured)")
  print("Reason: Without lists, all items are allowed")
elseif allow then
  -- When allow list is present, ignore list is not used
  local allowed = filter.isAllowed(itemName, itemData)
  if allowed then
    print("Status: ALLOWED")
    print("Reason: Item matches allow list")
    print("Note: Ignore list is not checked when allow list is present")

    -- Show why it's allowed
    if allow[itemName] == true then
      print("  - Direct name match in allow list")
    elseif itemTags then
      print("  - Tag match in allow list")
      -- Find which tag matched
      if type(itemTags) == "table" then
        for k, v in pairs(itemTags) do
          local tag = type(k) == "number" and v or k
          if filter.checkTagInList(tostring(tag), allow) then
            print("    Matched tag: " .. tostring(tag))
          end
        end
      end
    end
  else
    print("Status: IGNORED")
    print("Reason: Item does not match allow list")
    print("Note: Ignore list is not checked when allow list is present")
    print("  - Not in allow list by name")
    if itemTags then
      print("  - No matching tags in allow list")
    else
      print("  - Item has no tags to match")
    end
  end
elseif ignore then
  -- Only check ignore list when allow list is not present
  local notIgnored = filter.isNotIgnored(itemName, itemData)
  if notIgnored then
    print("Status: ALLOWED")
    print("Reason: Item is not in ignore list")
  else
    print("Status: IGNORED")
    print("Reason: Item matches ignore list")

    -- Show why it's ignored
    if ignore[itemName] == true then
      print("  - Direct name match in ignore list")
    elseif itemTags then
      print("  - Tag match in ignore list")
      -- Find which tag matched
      if type(itemTags) == "table" then
        for k, v in pairs(itemTags) do
          local tag = type(k) == "number" and v or k
          if filter.checkTagInList(tostring(tag), ignore) then
            print("    Matched tag: " .. tostring(tag))
          end
        end
      end
    end
  end
end

print()
print("Quarry behavior:")
if desired then
  print("  -> Item will be KEPT and stored in chest")
else
  print("  -> Item will be DROPPED as waste (on ground)")
end
