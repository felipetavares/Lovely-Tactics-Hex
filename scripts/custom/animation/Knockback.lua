
--[[===============================================================================================

Knockback
---------------------------------------------------------------------------------------------------
The animation of knockback when a characters receives damage.

=================================================================================================]]

-- Imports
local Animation = require('core/graphics/Animation')

-- Alias
local round = math.round
local abs = math.abs
local row2Angle = math.row2Angle
local angle2Coord = math.angle2Coord
local time = love.timer.getDelta

-- Constants
local defaultStep = 12

local Knockback = class(Animation)

---------------------------------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------------------------------

-- Constructor.
function Knockback:init(...)
  Animation.init(self, ...)
  self.knockTime = 0
  if self.param ~= nil then
    self.step = tonumber(self.param) or defaultStep
  else
    self.step = defaultStep
  end
end
-- Overrides Animation:setRow.
function Knockback:setRow(row)
  Animation.setRow(self, row)
  local dx, dy = angle2Coord(row2Angle(row))
  self.origX = self.sprite.offsetX
  self.origY = self.sprite.offsetY
  self.destX = self.origX + dx * self.step
  self.destY = self.origY - dy * self.step
  self.knockSpeed = 60 / self.duration * 2
end

---------------------------------------------------------------------------------------------------
-- Update movement
---------------------------------------------------------------------------------------------------

-- Overrides Animation:update.
function Knockback:update()
  Animation.update(self)
  self:updateTime()
  if self.knockTime > 1 then
    self.knockSpeed = -self.knockSpeed
    self:updateTime()
  end
  self:updatePosition()
end
-- Increments time.
function Knockback:updateTime()
  self.knockTime = self.knockTime + time() * self.knockSpeed
end
-- Sets position according to time.
function Knockback:updatePosition()
  local x = self.origX * (1 - self.knockTime) + self.destX * self.knockTime
  local y = self.origY * (1 - self.knockTime) + self.destY * self.knockTime
  self.sprite:setOffset(round(x), round(y))
end

return Knockback
