-- Item Tag Logger
-- Detects the first item in the turtle's inventory and logs its tags

---@diagnostic disable: undefined-global
---@type table
fs = fs
---@type table
os = os
---@type table
turtle = turtle
---@type table
textutils = textutils
---@type table
peripheral = peripheral

if not turtle then
  print("This program can only be executed by a turtle!")
  return
end

local utils = require("modules.utils")
local logFile = utils.getScriptPath("item_tags.log")

local function writeToFile(text)
  local f = fs.open(logFile, "w")
  if f then
    f.write(tostring(os.date()) .. " - " .. text)
    f.close()
  end
end

-- Try to find a peripheral that can get item tags
local tagPeripheral = nil
if peripheral then
  local sides = {"top", "bottom", "left", "right", "front", "back"}
  for _, side in ipairs(sides) do
    local periph = peripheral.wrap(side)
    if periph and periph.getItemTags then
      tagPeripheral = periph
      print("Found tag peripheral on side: " .. side)
      break
    end
  end
end

print("Item Tag Logger started")
print("Checking inventory for items...")
print()

-- Find first item in inventory
local itemSlot = nil
local itemData = nil

for i = 1, 16 do
  if turtle.getItemCount(i) > 0 then
    itemSlot = i
    itemData = turtle.getItemDetail(i)
    break
  end
end

if not itemData then
  print("No items found in inventory!")
  print("Please place an item in the turtle's inventory and run again.")
  return
end

print("Item found in slot " .. tostring(itemSlot) .. "!")
print()

local itemName = itemData.name
local itemCount = itemData.count
local itemDamage = itemData.damage
local itemTags = nil

-- Try to get tags from various sources
if itemData.tags then
  itemTags = itemData.tags
elseif itemData.tag then
  itemTags = itemData.tag
elseif tagPeripheral then
  -- Try to get tags from peripheral
  local ok, tags = pcall(tagPeripheral.getItemTags, itemName)
  if ok and tags then
    itemTags = tags
  end
end

local logEntry = "Item: " .. tostring(itemName)
logEntry = logEntry .. "\n  Slot: " .. tostring(itemSlot)
logEntry = logEntry .. "\n  Count: " .. tostring(itemCount)

if itemDamage and itemDamage ~= 0 then
  logEntry = logEntry .. "\n  Damage: " .. tostring(itemDamage)
end

if itemTags then
  if type(itemTags) == "table" then
    local tagCount = 0
    local tagList = {}
    for k, v in pairs(itemTags) do
      tagCount = tagCount + 1
      if type(k) == "number" then
        table.insert(tagList, tostring(v))
      else
        table.insert(tagList, tostring(k) .. " = " .. tostring(v))
      end
    end
    logEntry = logEntry .. "\n  Tags (" .. tagCount .. "):"
    for _, tag in ipairs(tagList) do
      logEntry = logEntry .. "\n    - " .. tag
    end
  else
    logEntry = logEntry .. "\n  Tags: " .. tostring(itemTags)
  end
else
  logEntry = logEntry .. "\n  No tags found"
end

-- Log full item data for debugging (serialized)
logEntry = logEntry .. "\n  Full item data:"
for k, v in pairs(itemData) do
  if k ~= "tags" and k ~= "tag" then
    if type(v) == "table" then
      logEntry = logEntry .. "\n    " .. tostring(k) .. " = " .. textutils.serialize(v)
    else
      logEntry = logEntry .. "\n    " .. tostring(k) .. " = " .. tostring(v)
    end
  end
end

print(logEntry)
writeToFile(logEntry)
print("\nLogged to: " .. logFile)
print("Program complete.")
