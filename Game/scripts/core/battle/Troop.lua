
--[[===============================================================================================

Troop
---------------------------------------------------------------------------------------------------
Manipulates the matrix of battler IDs to the instatiated in the beginning of the battle.

=================================================================================================]]

-- Imports
local Matrix2 = require('core/math/Matrix2')

-- Alias
local mod = math.mod

-- Constants
local sizeX = Config.troop.width
local sizeY = Config.troop.height
local baseDirection = 315 -- characters' direction at rotation 0

local Troop = class()

---------------------------------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------------------------------

-- Constructor. 
-- @param(grid : Matrix2) the matrix of battler IDs (optiontal, empty by default)
-- @param(r : number) the rotation of the troop (optional, 0 by default)
function Troop:init(data, r, AI)
  self.grid = Matrix2(sizeX, sizeY)
  self.members = {}
  local battlers = data.current
  for i = 1, #battlers do
    self.grid:set(battlers[i], battlers[i].x + 1, battlers[i].y + 1) 
    self.members[#self.members + 1] = battlers[i]
  end
  self.rotation = r or 0
  self.AI = AI
end
-- Creates a new troop from database data.
-- @param(troopID : number) the ID of the troop in the database
function Troop.fromData(troopID)
  local data = Database.troops[troopID + 1]
  local grid = Matrix2(sizeX, sizeY)
  for i = 1, sizeX do
    for j = 1, sizeY do
      local id = data.grid[i][j]
      grid:set(id, i, j)
    end
  end
  local AI = nil
  local ai = data.scriptAI
  if ai.path ~= '' then
    AI = require('custom/' .. ai.path)(ai.param)
  end
  return Troop(grid, nil, AI)
end
-- Creates a copy of this troop.
-- @param(rotation : number) rotation of the copy (optional)
-- @ret(Troop)
function Troop:clone(rotation)
  return Troop(self.grid:clone(), self.rotation, self.AI)
end

---------------------------------------------------------------------------------------------------
-- Rotation
---------------------------------------------------------------------------------------------------

-- Sets the troop rotation (and adapts the ID matrix).
-- @param(r : number) new rotation
function Troop:setRotation(r)
  for i = mod(r - self.rotation, 4), 1, -1 do
    self:rotate()
  end
end
-- Rotates by 90.
function Troop:rotate()
  local sizeX, sizeY = self.grid.width, self.grid.height
  local grid = Matrix2(sizeY, sizeX)
  for i = 1, sizeX do
    for j = 1, sizeY do
      local id = self.grid:get(i, j)
      grid:set(id, sizeY - j + 1, i)
    end
  end
  self.grid = grid
  self.rotation = mod(self.rotation + 1, 4)
end
-- Gets the character direction in degrees.
-- @ret(number)
function Troop:getCharacterDirection()
  return mod(baseDirection + self.rotation * 90, 360)
end

return Troop
  