
--[[===============================================================================================

SkillAction
---------------------------------------------------------------------------------------------------
The BattleAction that is executed when players chooses a skill to use.

=================================================================================================]]

-- Imports
local List = require('core/datastruct/List')
local TagMap = require('core/datastruct/TagMap')
local BattleAction = require('core/battle/action/BattleAction')
local MoveAction = require('core/battle/action/MoveAction')
local ActionInput = require('core/battle/action/ActionInput')
local PathFinder = require('core/battle/ai/PathFinder')
local PopupText = require('core/battle/PopupText')

-- Alias
local max = math.max
local isnan = math.isnan
local mathf = math.field
local time = love.timer.getDelta
local now = love.timer.getTime
local random = math.random
local round = math.round
local ceil = math.ceil

-- Constants
local elementCount = #Config.elements
local introTime = 22.5
local centerTime = 7.5
local targetTime = 2.2
local useTime = 2
local finishTime = 45

local SkillAction = class(BattleAction)

---------------------------------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------------------------------

-- Constructor. Creates the action from a skill ID.
-- @param(skillID : number) the skill's ID from database
function SkillAction:init(skillID)
  local data = Database.skills[skillID]
  self.data = data
  self.skillID = skillID
  local color = nil
  -- Skill type
  if data.type == 0 then
    color = 'general'
  elseif data.type == 1 then
    color = 'attack'
  elseif data.type == 2 then
    color = 'support'
  end
  BattleAction.init(self, data.range, data.radius, color)
  -- Effect formulas
  self.effects = {}
  for i = 1, #data.effects do
    self.effects[i] = {
      basicResult = loadformula(data.effects[i].basicResult, 'action, a, b, rand'),
      successRate = loadformula(data.effects[i].successRate, 'action, a, b, rand'),
      key = data.effects[i].key }
  end
  -- Cost formulas
  self.costs = {}
  for i = 1, #data.costs do
    self.costs[i] = {
      cost = loadformula(data.costs[i].value, 'action, att'),
      key = data.costs[i].key }
  end
  -- Status chances
  self.status = {}
  for i = 1, #(data.status or {}) do
    self.status[i] = {
      rate = loadformula(data.status[i].rate, 'action, a, b, rand'),
      id = data.status[i].id }
  end
  -- Store elements
  local e = {}
  for i = 1, #data.elements do
    e[data.elements[i].id + 1] = data.elements[i].value
  end
  for i = 1, elementCount do
    if not e[i] then
      e[i] = 0
    end
  end
  self.elementFactors = e
  self.tags = TagMap(data.tags)
end
-- Creates an SkillAction given the skill's ID in the database, depending on the skill's script.
-- @param(skillID : number) the skill's ID in database
function SkillAction.fromData(skillID)
  local data = Database.skills[skillID]
  if data.script.path ~= '' then
    local class = require('custom/' .. data.script.path)
    return class(skillID, data.script.param)
  else
    return SkillAction(skillID)
  end
end
-- Converting to string.
-- @ret(string) a string with skill's ID and name
function SkillAction:__tostring()
  return 'SkillAction (' .. self.skillID .. ': ' .. self.data.name .. ')'
end

---------------------------------------------------------------------------------------------------
-- Execution
---------------------------------------------------------------------------------------------------

-- Checks if the given character can use the skill, considering skill's costs
-- @param(user : Character)
-- @ret(boolean)
function SkillAction:canExecute(input)
  local att = input.user.battler.att
  local state = input.user.battler.state
  for i = 1, #self.costs do
    local cost = self.costs[i].cost(self, att)
    local key = self.costs[i].key
    if cost > state[key] then
      return false
    end
  end
  return true
end
-- Overrides BattleAction:onConfirm.
-- Executes the movement action and the skill's effect.
function SkillAction:execute(input)
  local moveAction = MoveAction(self.data.range)
  local moveInput = ActionInput(moveAction, input.user, input.target)
  moveInput.skipAnimations = input.skipAnimations
  local result = moveInput:execute(moveInput)
  if result.executed then    
    -- Skill use
    input.user.battler:onSkillUseStart(input)
    self:use(input)
    input.user.battler:onSkillUseEnd(input)
    return BattleAction.execute(self, input)
  else
    return { executed = false, endCharacterTurn = true }
  end
end

---------------------------------------------------------------------------------------------------
-- Effect result
---------------------------------------------------------------------------------------------------

-- Tells if a character may receive the skill's effects.
-- @param(char : Character)
function SkillAction:receivesEffect(char)
  return char.battler and char.battler:isAlive()
end
-- Calculates the final damage / heal for the target.
-- It considers all element bonuses provided by the skill data.
-- @param(input : ActionInput) the target character
-- @param(targetChar : Character)
-- @param(rand : function) the random function (optional)
-- @ret(table) an array of result values { attributeName, value }
-- @ret(boolean) true if there's a damage
function SkillAction:calculateEffectResults(input, targetChar, rand)
  rand = rand or random
  local dmg = false
  local points = {}
  for i = 1, #self.effects do
    local r = self:calculateEffectResult(self.effects[i], input, targetChar, rand)
    if r then
      dmg = dmg or r > 0
      points[#points + 1] = { value = r,
        key = self.effects[i].key }
    end
  end
  local status = {}
  if self.status then
    for i = 1, #self.status do
      local s = self.status[i]
      local r = s.rate(self, input.user.battler.att, targetChar.battler.att, rand)
      if rand() * 100 <= r then
        status[#status + 1] = s.id
        s = Database.status[s.id + 1]
        dmg = dmg or s.debuff
      end
    end
  end
  local results = { damage = dmg,
    points = points,
    status = status }
  return results
end
-- Calculates the final damage / heal for the target from an specific effect.
-- It considers all element bonuses provided by the skill data.
-- @param(effect : table) the effect data
-- @param(input : ActionInput) the target character
-- @param(targetChar : Character)
-- @param(rand : function) the random function (optional)
-- @ret(number) the result of the damage (nil if missed)
function SkillAction:calculateEffectResult(effect, input, targetChar, rand)
  local rate = effect.successRate(self, input.user.battler.att, 
    targetChar.battler.att, random)
  if rand() * 100 > rate then
    return nil
  end
  local result = effect.basicResult(self, input.user.battler.att, 
    targetChar.battler.att, rand)
  local bonus = 0
  local skillElements = self.elementFactors
  local target = targetChar.battler
  for i = 1, elementCount do
    bonus = bonus + skillElements[i] * target:element(i)
  end
  bonus = result * bonus
  return round(bonus + result)
end

---------------------------------------------------------------------------------------------------
-- Animations
---------------------------------------------------------------------------------------------------

-- The effect applied when the user is prepared to use the skill.
-- It executes animations and applies damage/heal to the targets.
function SkillAction:use(input)
  -- Intro time.
  _G.Fiber:wait(introTime)
  -- User's initial animation.
  local originTile = input.user:getTile()
  local dir = input.user:turnToTile(input.target.x, input.target.y)
  dir = math.angle2Row(dir) * 45
  input.user:loadSkill(self.data, dir)
  -- Cast animation
  FieldManager.renderer:moveToTile(input.target)
  _G.Fiber:fork(input.user.castSkill, input.user, self.data, dir)
  -- Animation in center target tile 
  --  (does not wait full animation, only the minimum time).
  if self.data.battleAnim.centerID >= 0 then
    local mirror = input.user.direction > 90 and input.user.direction <= 270
    local x, y, z = mathf.tile2Pixel(input.target:coordinates())
    local animation = BattleManager:playAnimation(self.data.battleAnim.centerID,
      x, y, z - 1, mirror)
  end
  _G.Fiber:wait(centerTime)
  -- Animation for each of affected tiles.
  self:allTargetsAnimation(input, originTile)
  -- Return user to original position and animation.
  input.user:finishSkill(originTile, self.data)
  -- Wait until everything finishes.
  _G.Fiber:wait(finishTime)
end

---------------------------------------------------------------------------------------------------
-- Target Animations
---------------------------------------------------------------------------------------------------

-- Executes individual animation for all the affected tiles.
-- @param(originTile : ObjectTile) the user's original tile
function SkillAction:allTargetsAnimation(input, originTile)
  local allTargets = self:getAllAffectedTiles(input)
  for i = #allTargets, 1, -1 do
    local tile = allTargets[i]
    for targetChar in tile.characterList:iterator() do
      if self:receivesEffect(targetChar) then
        self:singleTargetAnimation(input, targetChar, originTile)
      end
    end
  end
end
-- Executes individual animation for a single tile.
-- @param(targetChar : Character) the character that will be affected
-- @param(originTile : ObjectTile) the user's original tile
function SkillAction:singleTargetAnimation(input, targetChar, originTile)
  local results = self:calculateEffectResults(input, targetChar)
  targetChar.battler:onSkillEffectStart(targetChar, input, results)
  if #results.points == 0 and #results.status == 0 then
    -- Miss
    local pos = targetChar.position
    local popupText = PopupText(pos.x, pos.y - 20, pos.z - 10)
    popupText:addLine(Vocab.miss, Color.popup_miss, Font.popup_miss)
    popupText:popup()
  else
    local wasAlive = targetChar.battler:isAlive()
    self:popupResults(targetChar, results)
    if self.data.battleAnim.individualID >= 0 then
      local dir = targetChar:angleToPoint(originTile.x, originTile.y)
      local mirror = dir > 90 and dir <= 270
      local pos = targetChar.position
      BattleManager:playAnimation(self.data.battleAnim.individualID,
        pos.x, pos.y, pos.z - 10, mirror)
    end
    if results.damage and wasAlive then
      if self.data.radius > 1 then
        originTile = input.target
      end
      _G.Fiber:fork(function()
        targetChar:damage(self.data, originTile, results)
      end)
    end
    if targetChar.battler:isAlive() then
      targetChar:playAnimation(targetChar.idleAnim)
    end
  end
  targetChar.battler:onSkillEffectEnd(targetChar, input, results)
  _G.Fiber:wait(targetTime)
end
-- Applies results on the given battler and creates a popup for each value.
-- @param(pos : Vector) the character's position
-- @param(battler : Battler) the battler that will be affected
-- @param(results : table) the array of effect results
function SkillAction:popupResults(char, results)
  local pos = char.position
  local popupText = PopupText(pos.x, pos.y - 20, pos.z - 10)
  for i = 1, #results.points do
    local points = results.points[i]
    if points.value > 0 then
      local popupName = 'popup_dmg' .. points.key
      popupText:addLine(points.value, Color[popupName], Font[popupName])
    else
      local popupName = 'popup_heal' .. points.key
      popupText:addLine(-points.value, Color[popupName], Font[popupName])
    end
    char.battler:damage(points.key, points.value)
  end
  for i = 1, #results.status do
    local id = results.status[i]
    local s = char.battler.statusList:addStatus(id, char)
    local popupName = 'popup_status' .. id
    local color = Color[popupName] or Color.popup_status
    local font = Font[popupName] or Font.popup_status
    popupText:addLine('+' .. s.data.name, color, font)
  end
  popupText:popup()
end

return SkillAction
