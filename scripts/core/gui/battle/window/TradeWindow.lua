
--[[===============================================================================================

TradeWindow
---------------------------------------------------------------------------------------------------
Window that shows each item of the inventory to be moved to another inventory.

=================================================================================================]]

-- Imports
local Animation = require('core/graphics/Animation')
local GUI = require('core/gui/GUI')
local Button = require('core/gui/Button')
local GridWindow = require('core/gui/GridWindow')

-- Alias
local max = math.max
local floor = math.floor

local TradeWindow = class(GridWindow)

---------------------------------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------------------------------

-- Constructor.
-- @param(inventory : Inventory) the inventory from which the items will be transfered
-- @param(totalWeight : number) the max weight of this inventory
function TradeWindow:init(GUI, inventory, totalWeight)
  self.inventory = inventory
  self.remainingWeight = (totalWeight or math.huge) - inventory:getTotalWeight()
  GridWindow.init(self, GUI)
end
-- Creates a button for each item.
function TradeWindow:createButtons()
  for i = 1, #self.inventory do
    local slot = self.inventory[i]
    self:newItemButton(slot)
  end
end
function TradeWindow:newItemButton(slot)
  local item = Database.items[slot.id + 1]
  local text = item.name .. ' (' .. slot.count .. ')'
  local icon = item.icon.imagePath ~= '' and Animation.fromQuad(item.icon, GUIManager.renderer)
  local button = Button(self, text, icon, self.onButtonConfirm, self.buttonEnabled)
  button.item = item
  button.slot = slot
  button.onMove = self.onButtonMove
  return button
end

---------------------------------------------------------------------------------------------------
-- Button callbacks
---------------------------------------------------------------------------------------------------

-- Tells if a button is enabled.
-- A button is enabled if the item may be transfered to the other inventory.
function TradeWindow:buttonEnabled(button)
  local window = self.left or self.right
  return window.remainingWeight >= button.item.weight
end
-- When player chooses an item.
function TradeWindow:onButtonConfirm(button)
  local other = self.left or self.right
  local count = 1
  if button.slot.count > 1 then
    local maxCount = max(floor(other.remainingWeight / button.item.weight), button.slot.count)
    count = self:showCountWindow(maxCount)
    if count <= 0 then
      return
    end
  end
  other:addItem(button.slot.id, count)
  self:removeItem(button, count)
end
-- Changes active window to the other one when player presses right/left buttons.
function TradeWindow:onButtonMove(button, dx, dy)
  if dx > 0 then
    self:changeTradeWindow(self.right)
  elseif dx < 0 then
    self:changeTradeWindow(self.left)
  end
end
-- Sets the active window.
-- @param(window : TradeWindow) the other trade window
function TradeWindow:changeTradeWindow(window)
  if window and #window.buttonMatrix > 0 then
    local button = self:currentButton()
    if button then
      button:setSelected(false)
    end
    self.cursor:hide()
    self.GUI:setActiveWindow(window)
    button = window:currentButton()
    button:setSelected(true)
    window.cursor:show()
  end
end
-- Shows the count window.
function TradeWindow:showCountWindow(maxCount)
  self.GUI.countWindow:setMax(maxCount)
  self.GUI.countWindow:insertSelf()
  self.GUI.countWindow:show()
  self.GUI.countWindow:activate()
  local result = self.GUI:waitForResult()
  self.GUI.countWindow:hide()
  self.GUI.countWindow:removeSelf()
  self:activate()
  return result
end

---------------------------------------------------------------------------------------------------
-- Add / Remove
---------------------------------------------------------------------------------------------------

-- Adds items to this window's inventory.
function TradeWindow:addItem(id, count)
  if self.inventory:addItem(id, count) then
    local slot = self.inventory:getSlot(id)
    local button = self:newItemButton(slot)
    self:packWidgets()
    button:updatePosition(self.position)
    self.remainingWeight = self.remainingWeight - button.item.weight * count
  else
    for i = 1, #self.buttonMatrix do
      local button = self.buttonMatrix[i]
      if button.slot.id == id then
        button.slot = self.inventory:getSlot(id)
        local text = button.item.name .. ' (' .. button.slot.count .. ')'
        button:setText(text)
        self.remainingWeight = self.remainingWeight - button.item.weight * count
      end
    end
  end
end
-- Removes items from this window's inventory.
function TradeWindow:removeItem(button, count)
  self.remainingWeight = self.remainingWeight + button.item.weight * count
  local id = button.slot.id
  if self.inventory:removeItem(id, count) then
    button.slot = self.inventory:getSlot(id)
    local text = button.item.name .. ' (' .. button.slot.count .. ')'
    button:setText(text)
  else
    self:removeButton(button.index)
    if #self.buttonMatrix == 0 then
      self.cursor:hide()
      self:changeTradeWindow(self.left or self.right)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Properties
---------------------------------------------------------------------------------------------------

-- Overrides GridWindow:colCount.
function TradeWindow:colCount()
  return 1
end
-- Overrides GridWindow:rowCount.
function TradeWindow:rowCount()
  return 5
end
-- Overrides GridWindow:buttonWidth.
function TradeWindow:buttonWidth()
  return 100
end

return TradeWindow
