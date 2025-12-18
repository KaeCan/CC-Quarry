-- Block Tag Logger
-- Detects the first non-air block in front of the turtle and logs its tags

if not turtle then
  print("This program can only be executed by a turtle!")
  return
end

local logFile = "block-tags.log"

local function writeToFile(text)
  local f = fs.open(logFile, "w")
  if f then
    f.write(tostring(os.date()) .. " - " .. text)
    f.close()
  end
end

-- Try to find a peripheral that can get block tags
local tagPeripheral = nil
if peripheral then
  local sides = {"top", "bottom", "left", "right", "front", "back"}
  for _, side in ipairs(sides) do
    local periph = peripheral.wrap(side)
    if periph and periph.getBlockTags then
      tagPeripheral = periph
      print("Found tag peripheral on side: " .. side)
      break
    end
  end
end

print("Block Tag Logger started")
print("Waiting for a non-air block in front of the turtle...")
print()

-- Wait for first non-air block
while true do
  local success, data = turtle.inspect()

  if success then
    local blockName = data.name
    local blockState = data.state

    -- Skip air blocks
    local isAir = blockName and (blockName:lower():find("air") or blockName == "minecraft:air" or blockName == "air")

    if not isAir then
      -- Found a non-air block, log it and exit
      local blockTags = nil

      -- Try to get tags from various sources
      if data.tags then
        blockTags = data.tags
      elseif data.tag then
        blockTags = data.tag
      elseif tagPeripheral then
        -- Try to get tags from peripheral
        local ok, tags = pcall(tagPeripheral.getBlockTags, data.name)
        if ok and tags then
          blockTags = tags
        end
      end

      local logEntry = "Block: " .. tostring(blockName)

      if blockState then
        logEntry = logEntry .. "\n  State: " .. tostring(blockState)
      end

      if blockTags then
        if type(blockTags) == "table" then
          local tagCount = 0
          local tagList = {}
          for k, v in pairs(blockTags) do
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
          logEntry = logEntry .. "\n  Tags: " .. tostring(blockTags)
        end
      else
        logEntry = logEntry .. "\n  No tags found"
      end

      -- Log full block data for debugging (serialized)
      logEntry = logEntry .. "\n  Full inspect data:"
      for k, v in pairs(data) do
        if k ~= "tags" and k ~= "tag" then
          if type(v) == "table" then
            logEntry = logEntry .. "\n    " .. tostring(k) .. " = " .. textutils.serialize(v)
          else
            logEntry = logEntry .. "\n    " .. tostring(k) .. " = " .. tostring(v)
          end
        end
      end

      print("Block detected!")
      print(logEntry)
      writeToFile(logEntry)
      print("\nLogged to: " .. logFile)
      print("Program complete.")
      return
    end
  end

  sleep(0.5) -- Check every half second
end
