---@diagnostic disable: undefined-global
---@type table
turtle = turtle

local M = {}

M.direction = {front=0, right=1, back=2, left=3}

M.state = {
  depth = 0,
  posx = 1,
  posy = 1,
  facing = M.direction.front
}

function M.select(slot)
  if turtle.getSelectedSlot() == slot then
    return true
  end
  return turtle.select(slot)
end

function M.forward()
  while not turtle.forward() do
    M.select(1)
    turtle.dig()
    turtle.attack()
  end
  if M.state.facing == M.direction.front then
    M.state.posy = M.state.posy + 1
  elseif M.state.facing == M.direction.back then
    M.state.posy = M.state.posy - 1
  elseif M.state.facing == M.direction.right then
    M.state.posx = M.state.posx + 1
  else
    M.state.posx = M.state.posx - 1
  end
end

function M.up()
  while not turtle.up() do
    M.select(1)
    turtle.digUp()
    turtle.attackUp()
  end
end

function M.down()
  while not turtle.down() do
    M.select(1)
    turtle.digDown()
    turtle.attackDown()
  end
end

function M.turnRight()
  turtle.turnRight()
  M.state.facing = M.state.facing + 1
  if (M.state.facing > 3) then
    M.state.facing = 0
  end
end

function M.turnLeft()
  turtle.turnLeft()
  M.state.facing = M.state.facing - 1
  if (M.state.facing < 0) then
    M.state.facing = 3
  end
end

return M
