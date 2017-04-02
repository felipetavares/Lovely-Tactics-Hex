
--[[===========================================================================

TileGUI
-------------------------------------------------------------------------------
ObjectTile graphics for battle interface.

=============================================================================]]

-- Imports
local Animation = require('core/graphics/Animation')

-- Alias
local tile2Pixel = math.field.tile2Pixel
local max = math.max

-- Constants
local tileW = Config.grid.tileW
local tileH = Config.grid.tileH
local tileAnimID = Config.gui.tileAnimID
local tileHLAnimID = Config.gui.tileHLAnimID

local TileGUI = require('core/class'):new()

-- @param(tile : ObjectTile) the tile this object belongs to.
function TileGUI:init(tile)
  local renderer = FieldManager.renderer
  local x, y, z = tile2Pixel(tile:coordinates())
  x = x - tileW / 2
  y = y - tileH / 2
  if Config.gui.tileAnimID >= 0 then
    local baseAnim = Database.animOther[tileAnimID + 1]
    self.baseAnim = Animation.fromData(baseAnim, renderer)
    self.baseAnim.sprite:setXYZ(x, y, z)
  end
  if Config.gui.tileHLAnimID >= 0 then
    local hlAnim = Database.animOther[tileHLAnimID + 1]
    self.highlightAnim = Animation.fromData(hlAnim, renderer)
    self.highlightAnim.sprite:setXYZ(x, y, z)
  end
  self.x, self.y, self.h = tile:coordinates()
  self:hide()
end

function TileGUI:update()
  if self.highlightAnim then
    self.highlightAnim:update()
  end
  if self.baseAnim then
    self.baseAnim:update()
  end
end

-- Updates graphics pixel depth according to the terrains' 
--  depth in this tile's coordinates.
function TileGUI:updateDepth()
  local tiles = FieldManager.currentField.terrainLayers[self.h]
  local maxDepth = tiles[1].grid[self.x][self.y].depth
  for i = #tiles, 2, -1 do
    maxDepth = max(maxDepth, tiles[i].grid[self.x][self.y].depth)
  end
  if self.baseAnim then
    self.baseAnim.sprite:setOffset(nil, nil, maxDepth / 2)
  end
  if self.highlightAnim then
    self.highlightAnim.sprite:setOffset(nil, nil, maxDepth / 2 - 1)
  end
end

-- Selects / deselects this tile.
-- @param(value : boolean) true to select, false to deselect
function TileGUI:setSelected(value)
  if self.highlightAnim then
    self.highlightAnim.sprite:setVisible(value)
  end
end

-- Sets color to the color with the given label.
-- @param(name : string) color label
function TileGUI:setColor(name)
  self.colorName = name
  if name == nil or name == '' then
    name = 'nothing'
  end
  name = 'tile_' .. name
  if not self.selectable then
    name = name .. '_off'
  end
  local c = Color[name]
  self.baseAnim.sprite:setColor(c)
end

-- Shows tile edges.
function TileGUI:show()
  if self.baseAnim then
    self.baseAnim.sprite:setVisible(true)
  end
end

-- Hides tile edges.
function TileGUI:hide()
  if self.baseAnim then
    self.baseAnim.sprite:setVisible(false)
  end
  self:setSelected(false)
end

return TileGUI
