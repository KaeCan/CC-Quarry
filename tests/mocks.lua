local M = {}

function M.createTurtle()
    local inventory = {}
    local selectedSlot = 1
    local fuelLevel = 0
    -- local position = {x=0, y=0, z=0, facing=0} -- 0=North, 1=East, 2=South, 3=West

    local mock = {}

    -- Inventory Management
    function mock.select(slot)
        if slot < 1 or slot > 16 then return false end
        selectedSlot = slot
        return true
    end

    function mock.getSelectedSlot()
        return selectedSlot
    end

    function mock.getItemCount(slot)
        slot = slot or selectedSlot
        return inventory[slot] and inventory[slot].count or 0
    end

    function mock.getItemDetail(slot)
        slot = slot or selectedSlot
        if not inventory[slot] then return nil end
        return {
            name = inventory[slot].name,
            count = inventory[slot].count,
            damage = inventory[slot].damage or 0
        }
    end

    -- Movement (Always succeed for unit tests unless configured otherwise)
    function mock.forward() return true end
    function mock.back() return true end
    function mock.up() return true end
    function mock.down() return true end
    function mock.turnLeft() return true end
    function mock.turnRight() return true end

    -- Fuel
    function mock.getFuelLevel() return fuelLevel end
    function mock.refuel(count)
        -- Simplified refuel logic
        if mock.getItemCount(selectedSlot) > 0 then
            fuelLevel = fuelLevel + 80
            inventory[selectedSlot].count = inventory[selectedSlot].count - 1
            if inventory[selectedSlot].count <= 0 then inventory[selectedSlot] = nil end
            return true
        end
        return false
    end

    -- Digging
    function mock.dig() return true end
    function mock.digUp() return true end
    function mock.digDown() return true end

    -- Inspection
    function mock.inspect() return false, "No block to inspect" end
    function mock.inspectUp() return false, "No block to inspect" end
    function mock.inspectDown() return false, "No block to inspect" end

    -- Custom Helpers for Tests
    function mock._setInventory(slot, name, count, damage)
        inventory[slot] = {name=name, count=count, damage=damage or 0}
    end

    function mock._setFuelLevel(level)
        fuelLevel = level
    end

    return mock
end

return M
