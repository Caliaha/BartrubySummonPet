BartrubySummonPet = LibStub("AceAddon-3.0"):NewAddon("BartrubySummonPet", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

local LQT = LibStub("LibQTip-1.0")

local EXCLUDEDZONES = {}
EXCLUDEDZONES["Proving Grounds"] = true -- This can probably be removed, I'm fairly sure zones are localized

local CHEFHATBUFFID = 67556
local PIERRE = 1204
local RAGNAROS = 297
COOKINGPETS = { }

--local EXCLUDEDPETS = {}

function BartrubySummonPet:OnInitialize()
 local defaults = {
  global = {
   enabled = true,
   tooltip = true,
   x = 0,
   y = 0,
   mounts = {
    ['*'] = nil,
   },
  },
  char = {
   enabled = true,
   battlepet = nil,
   multispecs = false,
   stealth = false,
   mount = false,
   useglobal = false,
   chefhat = false,
   ver = 0,
   battlepets = {
    default = nil,
	mounts = {
	 ['*'] = nil,
	},
	sets = {
	 ['*'] = nil,
	},
	specs = {
	 ['*'] = nil,
	},
	pets = {
	 ['*'] = nil,
	},
	druidforms = {
	 ['*'] = nil,
	},
   },
   mounts = { -- Deprecated from here on down
    ['*'] = {
	 battlepet = nil,
	},
   },
   specs = {
    ['*'] = {
	 battlepet = nil,
	},
   },
   pets = {
    ['*'] = {
	 battlepet = nil,
	},
   },
   sets = {
    ['*'] = {
	 battlepet = nil,
	},
   },
   druidforms = {
    ['*'] = {
	 battlepet = nil,
	},
   },
  },
 }

 self.db = LibStub("AceDB-3.0"):New("BartrubySummonPetDB", defaults, true)
 self.db.RegisterCallback(self, "OnProfileChanged", "DBChange")
 self.db.RegisterCallback(self, "OnProfileCopied", "DBChange")
 self.db.RegisterCallback(self, "OnProfileReset", "DBChange")
 
 if (self.db.char.ver < 1) then
  self:UpgradeDB()
 end
 
 LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("BartrubySummonPet", self:GenerateOptions())
 self.configFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("BartrubySummonPet", "BartrubySummonPet")
 
 self:RegisterChatCommand("bartrubysummonpet","HandleIt")
 self:RegisterChatCommand("bsp","HandleIt")
 self:RegisterEvent("PLAYER_LOGIN")
 self:RegisterEvent("UPDATE_STEALTH", "StealthStuff")
 -- May need to register UPDATE_SUMMONPETS_ACTION
 self.debug = false
end

function BartrubySummonPet:OnEnable()
 self:SecureHook("MoveForwardStart", "SummonPet")
 self:SecureHook("ToggleAutoRun", "SummonPet")
end

function BartrubySummonPet:OnDisable()
 self:UnregisterAllEvents() -- Might be unnecessary
 self.bpFrame:Hide()
end

function BartrubySummonPet:PLAYER_LOGIN()
 self:UnregisterEvent("PLAYER_LOGIN")
 
 --if not PetJournal_OnLoad then
  --UIParentLoadAddOn('Blizzard_Collections')
 --end
 
 local frame = CreateFrame("Frame", nil, PetPaperDollFrameCompanionFrame)
 frame:SetPoint("TOPLEFT", PetPaperDollFrameCompanionFrame, "TOPRIGHT", self.db.global.x, self.db.global.y)
 frame:SetWidth(64)
 frame:SetHeight(64)
 --[[frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
      tile = true, tileSize = 16, edgeSize = 16, 
      insets = { left = 4, right = 4, top = 4, bottom = 4 }});
 frame:SetBackdropColor(1,1,1,1) ]]--
 frame.texture = frame:CreateTexture(nil, 'BACKGROUND')
 frame.texture:SetAllPoints(true)
 frame.texture:SetTexture("Interface\\ICONS\\spell_nature_spiritwolf.blp")
 frame.enabled = frame:CreateTexture(nil, 'HIGH')
 frame.enabled:SetWidth(32)
 frame.enabled:SetHeight(32)
 frame.enabled:SetPoint("BOTTOMRIGHT")
 
 frame:SetScript("OnShow", function(self) BartrubySummonPet:PlaceIcon("show") end)
 frame:SetScript("OnReceiveDrag", function(self) BartrubySummonPet:CheckCursor(nil) end)
 frame:SetScript("OnMouseUp", function(self, button) BartrubySummonPet:CheckCursor(button); BartrubySummonPet:DragStop(self, button) end)
 frame:SetScript("OnMouseDown", function(self, button) BartrubySummonPet:DragStart(self, button) end)
 frame:SetScript("OnHide", function(self) BartrubySummonPet:PlaceIcon("hide") end)
 frame:SetScript("OnEnter", function()
  if (not self.db.global.tooltip) then return end
  local tooltip = LQT:Acquire("BartrubySummonPet", 1, "LEFT")
  self.tooltip = tooltip
  local battlepet = self:GetBattlepet()
  local fakebattlepet = self:GetBattlepet(true)
  if (battlepet == "RANDOMALL") then
   tooltip:AddLine("Random Pet")
  elseif (battlepet == "RANDOMFAVORITE") then
   tooltip:AddLine("Random Favorite Pet")
	elseif (battlepet ~= nil) then
		local _, name = self:GetIDFromCreatureID(battlepet)
		tooltip:AddLine(name)
	end
  if (battlepet == nil) then
   tooltip:AddLine("No pet will be summoned")
   if (self.db.char.enabled) then
    tooltip:AddLine("Active pets will be dismissed")
   end
  end
  if (self.db.char.mount) then
   if (self.db.char.useglobal) then
    tooltip:AddLine("Summoning based on current mount (global list)")
   else
    tooltip:AddLine("Summoning based on current mount")
   end
  end
  if (self.db.char.chefhat) then
   tooltip:AddLine("Will summon cooking pet when a Chef's Hat is equipped")
  end
  if (self.db.char.stealth) then
   tooltip:AddLine("Will attempt to dismiss pet while stealthed")
  end
  if (self.db.char.multispecs) then
   tooltip:AddLine("Summoning based on specialization")
  end
  if (fakebattlepet == "DRUIDFORMS") then
   tooltip:AddLine("Summoning based on druid forms")
  elseif (fakebattlepet == "EQUIPMENTSETS") then
   tooltip:AddLine("Summoning based on equipment sets")
  elseif (fakebattlepet == "MINIONPET") then
   tooltip:AddLine("Summoning based on Hunter/Warlock pets")
  end
 
 --[[ enabled = true,
   bttlepet = nil,
   multispecs = false,
   stealth = false,
   mount = false,
   useglobal = false,
   chefhat = false, ]]--
  
  tooltip:AddLine("Right-click to clear icon and dismiss pet")
  tooltip:AddLine("Control Right-click to disable/enable this addon for this character")
  tooltip:AddLine("Alt Left-click to toggle summoning random favorites")
  tooltip:AddLine("Alt Right-click to toggle summoning random pets")
  tooltip:AddLine("Shift Left-click to drag the square to another location")
  tooltip:AddLine("/bsp reset to restore the square to it's original location")
  tooltip:AddLine("/bsp to bring up the settings for this addon")
  tooltip:SmartAnchorTo(frame)
  tooltip:Show()
 end)
 frame:SetScript("OnLeave", function() LQT:Release(self.tooltip) self.tooltip = nil end)
 frame:SetMovable(true)
 frame:EnableMouse(true)
 frame:SetFrameStrata("FULLSCREEN")
 frame:Show()
 self.bpFrame = frame
 
 if (Rematch) then
  RematchJournal:SetScript("OnShow", function(self)
              BartrubySummonPet.bpFrame:SetParent("RematchJournal")
			  BartrubySummonPet.bpFrame:SetPoint("TOPLEFT", RematchJournal, "TOPRIGHT", BartrubySummonPet.db.global.x, BartrubySummonPet.db.global.y)
			 end)
  RematchJournal:SetScript("OnHide", function(self)
              BartrubySummonPet.bpFrame:SetParent("PetPaperDollFrameCompanionFrame")
			  BartrubySummonPet.bpFrame:SetPoint("TOPLEFT", PetPaperDollFrameCompanionFrame, "TOPRIGHT", BartrubySummonPet.db.global.x, BartrubySummonPet.db.global.y)
			 end)
 end
end

function BartrubySummonPet:DBChange()
 self.bpFrame:ClearAllPoints()
 if (RematchJournal and RematchJournal:IsVisible()) then
  self.bpFrame:SetPoint("TOPLEFT", RematchJournal, "TOPRIGHT", self.db.global.x, self.db.global.y)
 else
  self.bpFrame:SetPoint("TOPLEFT", PetPaperDollFrameCompanionFrame, "TOPRIGHT", self.db.global.x, self.db.global.y)
 end
end

function BartrubySummonPet:HandleIt(input)
 if not input then return end

 local command, nextposition = self:GetArgs(input,1,1)

 if (command == "reset") then
  self.db.global.x = 0
  self.db.global.y = 0
  self:DBChange()
  return
 end
 
 if (command == "spec") then
  if (self.db.char.multispecs) then
   self.db.char.multispecs = false
   self:Print("Set pet per spec to false.")
  else
   self.db.char.multispecs = true
   self:Print("Set pet per spec to true.")
  end
  self:PlaceIcon()
  return
 end
 
 if (command == "mount") then
  if (self.db.char.mount) then
   self.db.char.mount = false
   self:Print("Set summon pet while mounted to false.")
  else
   self.db.char.mount = true
   self:Print("Set summon pet while mounted to true.")
  end
  self:PlaceIcon()
  return
 end
 
 if (command == "pets") then
  if (self:GetBattlepet(true) == "MINIONPET") then
   self:SetBattlepet(nil, true)
   self:Print("Will no longer summon battlepets based on current pet")
  else
   self:SetBattlepet("MINIONPET", true)
   self:Print("Will summon battlepets based on current pet")
   local _, class, _ = UnitClass("player")
   if (class ~= "HUNTER" and class ~= "WARLOCK") then
    self:Print("This mode is mainly intended for Hunter and Warlocks but will still be enabled, repeat the command to disable")
   end
  end
  self:PlaceIcon()
  return
 end
 
 if (command == "sets") then
  if (self:GetBattlepet(true) == "EQUIPMENTSETS") then
   self:SetBattlepet(nil, true)
   self:Print("Will no longer summon battlepets based on current equipment set")
  else
   self:SetBattlepet("EQUIPMENTSETS", true)
   self:Print("Will summon battlepets based on current equipment set")
  end
  self:PlaceIcon()
  return
 end
 
 if (command == "druid") then
  if (self:GetBattlepet(true) == "DRUIDFORMS") then
   self:SetBattlepet(nil, true)
   self:Print("Will no longer summon battlepets based on current equipment set")
  else
   local _, class, _ = UnitClass("player")
   if (class ~= "DRUID") then self:Print("This command is only available to druids") return end
   
   self:SetBattlepet("DRUIDFORMS", true)
   self:Print("Will summon battlepets based on current druid form")
  end
  self:PlaceIcon()
  return
 end
 
 if (command == "global") then
  if (self.db.char.useglobal) then
   self:Print("Will no longer use global mount list")
   self.db.char.useglobal = false
  else
   self:Print("Will use global mount list")
   self.db.char.useglobal = true
  end
  self:PlaceIcon()
  return
 end
 
 if (command == "favorite") then
  if (self:GetBattlepet(true) == "RANDOMFAVORITE") then
   self:SetBattlepet(nil)
   self:Print("Will no longer summon random favorite battle pets")
  else
   self:SetBattlepet("RANDOMFAVORITE")
   self:Print("Will summon random favorite battle pets")
  end
  self:SummonPet()
  self:PlaceIcon()
  return
 end
 
 if (command == "random") then
  if (self:GetBattlepet(true) == "RANDOMALL") then
   self:SetBattlepet(nil)
   self:Print("Will no longer summon random battle pets")
  else
   self:SetBattlepet("RANDOMALL")
   self:Print("Will summon random battle pets")
  end
  self:SummonPet()
  self:PlaceIcon()
  return
 end

 if (command == "help") then
  self:Print("Commands are as following:")
  self:Print("reset -> Resets position of battlepet square")
  self:Print("spec -> Toggles summoning based on active specialization")
  self:Print("pets -> Toggles summoning based on current pet or demon (warlocks/hunters only)")
  self:Print("sets -> Toggles summoning based on current equipment set")
  self:Print("druid -> Toggles summoning based on current equipment set")
  self:Print("mount -> Toggles summoning based on current active mount")
  self:Print("global -> Toggles use of global mount list for current character")
  self:Print("favorite -> Toggles summoning based on favorite pets")
  self:Print("random -> Toggles summoning of random pet")
  self:Print("pets and sets and druid are exclusive with each other, only one may be active")
  self:Print("Commands must be preceded by /bartrubysummonpet or /bsp")
  return
 end
 
 if (self:GetBattlepet(true) == "DRUIDFORMS") then
  self:Print("Currently set to summon battlepets based on currently active druid form")
 end
 
 if (self:GetBattlepet(true) == "EQUIPMENTSETS") then
  self:Print("Currently set to summon battlepets based on current equipment set")
 end
 
 if (self:GetBattlepet(true) == "MINIONPET") then
  self:Print("Currently set to summon battlepets based on currently active pet")
 end
 
 if (self.db.char.multispecs) then
  self:Print("Currently set to summon battlepets based on currently active spec")
 end
 
 if (self.db.char.mount) then
  self:Print("Currently set to summon a different battlepet based on mount")
 end
 
 if (self.db.char.useglobal) then
  self:Print("Currently using the global mount list")
 end
 
 InterfaceOptionsFrame_OpenToCategory("BartrubySummonPet")
 InterfaceOptionsFrame_OpenToCategory("BartrubySummonPet")
end

function BartrubySummonPet:CheckCursor(button)
 --self:Print(GetCursorInfo())
 local type, id = GetCursorInfo()

 if type == "companion" then
	print(GetCompanionInfo("CRITTER", id))
end

	if (type == "companion") then
		creatureID, creatureName = GetCompanionInfo("CRITTER", id)
		self:SetBattlepet(id)
		self:PlaceIcon()
		self:SummonPet()
		ClearCursor()
		return
	end
 if (button == "LeftButton") then
  if (IsAltKeyDown() and not IsControlKeyDown()) then
   if (self:GetBattlepet(true) == "RANDOMFAVORITE") then
    self:SetBattlepet(nil)
   else
    self:SetBattlepet("RANDOMFAVORITE")
   end
  end
  self:PlaceIcon()
  self:SummonPet()
 end
 if (button == "RightButton") then
  if (IsControlKeyDown() and not IsAltKeyDown()) then
   if (self.db.char.enabled) then
    self.db.char.enabled = false
   else
    self.db.char.enabled = true
   end
  elseif (not IsShiftKeyDown()) then
   self:SetBattlepet(nil, true)
  end
  if (IsAltKeyDown() and not IsControlKeyDown()) then
  if (self:GetBattlepet(true) == "RANDOMALL") then
    self:SetBattlepet(nil, true)
   else
    self:SetBattlepet("RANDOMALL")
   end
  end
  self:PlaceIcon()
  self:SummonPet()
 end
end

function BartrubySummonPet:GetIDFromCreatureID(id)
	for i=1, GetNumCompanions("CRITTER") do
		local creatureID, creatureName, creatureSpellID, icon, issummoned = GetCompanionInfo("CRITTER", i)
		if (creatureID == id) then
			return i, creatureName, creatureSpellID, icon, issummoned
		end
	end
end

function BartrubySummonPet:PlaceIcon(register)
 if (register == "show") then
  --self:RegisterEvent("PET_JOURNAL_LIST_UPDATE", "PlaceIcon") -- Might not be needed?
  --self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "PlaceIcon")
  --self:RegisterEvent("UNIT_PET", "PlaceIcon")
  --self:RegisterEvent("EQUIPMENT_SETS_CHANGED", "PlaceIcon")
  --self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "PlaceIcon")
  --if (self.db.char.mount) then self:RegisterEvent("UNIT_AURA", "PlaceIcon") end
 elseif (register == "hide") then
  --self:UnregisterEvent("PET_JOURNAL_LIST_UPDATE") -- Might not be needed?
  --self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  --self:UnregisterEvent("UNIT_PET", "PlaceIcon")
  --self:UnregisterEvent("EQUIPMENT_SETS_CHANGED")
  --self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM")
 end
 --if(self.debug) then self:Print("PlaceIcon() Called") end
 if (not self.bpFrame:IsVisible()) then return end -- If we can't be seen then don't do anything
 
 -- May need to add checks to see if the pet exists
 if (self.db.char.enabled) then
  self.bpFrame.enabled:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
 else
  self.bpFrame.enabled:SetTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
 end
 
 local id = self:GetBattlepet()
 
 local noPetIcon = "Interface\\ICONS\\spell_nature_spiritwolf.blp"

 
 
 if (not id) then
  self.bpFrame.texture:SetTexture(noPetIcon);
  return 
 elseif (id == "RANDOMFAVORITE") then
  self.bpFrame.texture:SetTexture("Interface\\ICONS\\INV_Misc_Platnumdisks.blp")
  return
 elseif (id == "RANDOMALL") then
  self.bpFrame.texture:SetTexture("Interface\\ICONS\\spell_Shaman_Measuredinsight.blp")
  return
 end
 
 local _, _, _, icon = self:GetIDFromCreatureID(id)
 self.bpFrame.texture:SetTexture(icon)
end

function BartrubySummonPet:GetBattlepet(noFooling)
-- change id to creatureID
 local id = nil
 
 if (self.db.char.mount and IsMounted() and not noFooling) then -- If we have pet assigned to this mount then return it, else continue on and find another.
  if (self.db.char.useglobal) then
   id = self.db.global.mounts[self:GetCurrentlySummonedMount()]
  else
   id = self.db.char.battlepets.mounts[self:GetCurrentlySummonedMount()]
  end
  if (id) then return id end
 end
 
 if (self.db.char.multispecs) then
  local _, name, _, _, _, _, _ = GetSpecializationInfo(GetSpecialization())
  id = self.db.char.battlepets.specs[name]
 else
  id = self.db.char.battlepets.default
 end
 
 if (noFooling) then
  return id
 end
 
 if (id == "MINIONPET") then
  local name, _ = UnitName("pet")
  if (name == nil) then
   name = "LONGENOUGHTOHOPEFULLYNOTBEAVALIDPETNAME"
  end
  id = self.db.char.battlepets.pets[name]
 end
 
 if (id == "EQUIPMENTSETS") then
  local name = self:GetCurrentlyEquippedSet()
  id = self.db.char.battlepets.sets[name]
 end
 
 if (id == "DRUIDFORMS") then
  form = GetShapeshiftForm()
  id = self.db.char.battlepets.druidforms[form]
 end
 
 return id
end

function BartrubySummonPet:SetBattlepet(id, noFooling)
 local battlepet = nil
 local battlepetName = "NO PET"
 local creatureID = nil
 local creatureName = nil
 
 if (id == "RANDOMALL") then
  battlepetName = "Random Pets"
 elseif (id == "RANDOMFAVORITE") then
  battlepetName = "Random Favorite"
 elseif (id and not noFooling) then
 --if (not noFooling and id) then
  --battlepetName = select(8, C_PetJournal.GetPetInfoByPetID(id))
  --local _, customName, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(id)
  
  creatureID, creatureName = GetCompanionInfo("CRITTER", id)
  battlepetName = creatureName
  --[[if (customName) then
   battlepetName = customName .. " (" .. name .. ")"
  else
   battlepetName = name
  end ]]--
 end
 
 
 if (self.db.char.mount and IsMounted() and not noFooling) then -- Mounted takes priority but don't assign modifiers
  local mount = self:GetCurrentlySummonedMount()
  if (self.db.char.useglobal) then
   self.db.global.mounts[mount] = id
  else
   self.db.char.battlepets.mounts[mount] = id
  end
   
  self:Print("Set", battlepetName, "for", mount)
  return
 end
 
 if (self.db.char.multispecs) then
  local currentSpec = GetSpecialization()
  local _, name, _, _, _, _, _ = GetSpecializationInfo(currentSpec)
  battlepet = self.db.char.battlepets.specs[name]
 else
  battlepet = self.db.char.battlepets.default
 end
 
 if (battlepet == "MINIONPET" and not noFooling) then
  local petName, _ = UnitName("pet")
  if (petName == nil) then
   self:Print("No minion summoned, setting battlepet for when no minions are out")
   petName = "LONGENOUGHTOHOPEFULLYNOTBEAVALIDPETNAME"
  else
   self:Print("Set",battlepetName,"for",petName)
  end
  self.db.char.battlepets.pets[petName] = id
 elseif (battlepet == "EQUIPMENTSETS" and not noFooling) then
  local equipSet = self:GetCurrentlyEquippedSet()
  if (equipSet == "NOVALIDEQUIPMENTSETS") then
   self:Print("No valid set equipped, setting battlepet for when no valid sets are equipped")
  else
   self:Print("Set",battlepetName,"for equipment set:",equipSet)
  end
  self.db.char.battlepets.sets[equipSet] = id
 elseif (battlepet == "DRUIDFORMS" and not noFooling) then
  local form = GetShapeshiftForm()
  if (form == nil) then form = 0 end
  self.db.char.battlepets.druidforms[form] = id
 else
  if (self.db.char.multispecs) then
   local currentSpec = GetSpecialization()
   local _, name, _, _, _, _, _ = GetSpecializationInfo(currentSpec)
   self.db.char.battlepets.specs[name] = id
   if (battlepetName ~= "NO PET") then
    self:Print("Set",battlepetName,"for",name)
   end
  else
   self.db.char.battlepets.default = creatureID
  end
 end
end

function BartrubySummonPet:GetCurrentSummonedPet()
	for i=1, GetNumCompanions("CRITTER") do
		local creatureID, creatureName, creatureSpellID, icon, issummoned = GetCompanionInfo("CRITTER", i)
		if issummoned then
			return i, creatureID, creatureName
		end
	end
	return false, false, false
end

function BartrubySummonPet:SummonPet() -- This function gets called everytime we initiate forward movement or toggle on autorun
 -- Things to check for: other pets (guild, argent tourney) -Probably not going to bother with this
	local id = nil
 
 if (not self.db.char.enabled or InCombatLockdown() or UnitIsDeadOrGhost("player") or IsStealthed() or IsFalling() or EXCLUDEDZONES[GetRealZoneText()]) then return end
 
 local creatureID, mode = self:GetBattlepet()
	if creatureID then
		id = self:GetIDFromCreatureID(creatureID)
	end
 
	
 local currentPet = self:GetCurrentSummonedPet()

 if (id == "RANDOMFAVORITE") then
  if (currentPet) then -- If we are set to summon a random favorite pet then check if the current pet is a favorite; if not then summon
   local _, _, _, _, _, _, isFavorite = C_PetJournal.GetPetInfoByPetID(currentPet)
   if (not isFavorite) then
    C_PetJournal.SummonRandomPet(true)
   end
  else
   C_PetJournal.SummonRandomPet(true)
  end
  return
 end
 if (id == "RANDOMALL") then
  if (not currentPet) then
   C_PetJournal.SummonRandomPet(false)
  end
  return
 end
 
 if (currentPet == false and id == nil) then return end -- No pet out and no pet to summon; do nothing
 if (currentPet ~= false and id == nil) then print('Attempting to dismiss pet') DismissCompanion("CRITTER") end -- Pet out but should be dismissed; dismiss current pet
 if (currentPet ~= id and id ~= nil) then print('Attempting to summon', id) CallCompanion("CRITTER", id) end -- No or incorrect pet is out; summon
end

local xB = 0
local yB = 0
function BartrubySummonPet:DragStart(frame, button)
 if (button == "LeftButton" and IsShiftKeyDown() and not frame.isMoving) then
  frame.isMoving = true
  frame:StartMoving()
  local _, _, _, x, y = frame:GetPoint()
  xB = x
  yB = y
  --self:Print(xB, yB)
 end
end

function BartrubySummonPet:StealthStuff()
 if (not self.db.char.stealth) then return end
 
 if (IsStealthed()) then
  --self:Print("In Stealth, dismissing pet")
  if (InCombatLockdown()) then return end -- Can't dismiss pet in combat
  local currentPet = C_PetJournal.GetSummonedPetGUID()
  if (not currentPet) then return end -- No pet to dismiss
  C_PetJournal.SummonPetByGUID(currentPet)
 else
  --self:Print("Not in stealth, summoning pet")
  self:SummonPet()
 end
end

function BartrubySummonPet:IsChefHatEquipped()
 local i=1
 repeat
   local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
   i = i+1
   if (spellId == CHEFHATBUFFID) then -- Found the chef's hat
      return true
   end
   if (not name) then
      return false
   end
 until(i > 40)
 return false
end

function BartrubySummonPet:DragStop(frame, button)
 if (button == "LeftButton" and frame.isMoving == true) then
  frame.isMoving = false

  local _, _, _, x, y = frame:GetPoint()
  frame:StopMovingOrSizing()

  local xDelta = x - xB
  local yDelta = y - yB

  self.db.global.x = xDelta + self.db.global.x
  self.db.global.y = yDelta + self.db.global.y
  self:DBChange()
 end
end

function BartrubySummonPet:GetCurrentlyEquippedSet()
 for i=0, C_EquipmentSet.GetNumEquipmentSets() do
  local name, _, _, isEquipped, _, _, _, _, _ = C_EquipmentSet.GetEquipmentSetInfo(i)
  if (isEquipped) then return name end
 end
 
 return "NOVALIDEQUIPMENTSETS"
end

function BartrubySummonPet:GetCurrentlySummonedMount()
 local mounts = C_MountJournal.GetMountIDs()
 for k, v in pairs(mounts) do
  local creatureName, _, _, active, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoByID(v)
  if (active) then
   return creatureName
  end
 end
 
 return "NOVALIDMOUNTS" -- Probably shouldn't ever happen, idk
end

function BartrubySummonPet:GenerateOptions()
 return {
  name = "BartrubySummonPet",
  type = "group",
  args = {
   enabled = {
    name = "Enabled",
    order = 1,
    type = "toggle",
    set = function(i, v) self.db.char.enabled = v self:PlaceIcon() self:SummonPet() end,
    get = function(i) return self.db.char.enabled end
   },
   tooltip = {
    name = "Tooltip",
	desc = "Show tooltip when mousing over pet icon",
	order = 1.5,
	type = "toggle",
	set = function(i, v) self.db.global.tooltip = v end,
	get = function(i) return self.db.global.tooltip end,
   },
   specialization = {
    name = "Specializations",
	desc = "Use different battlepets for each spec",
	order = 2,
	type = "toggle",
	set = function(i, v) self.db.char.multispecs = v self:PlaceIcon() self:SummonPet() end,
	get = function(i) return self.db.char.multispecs end,
   },
   stealth = {
    name = "Stealth",
	desc = "Dismiss pet while stealthed",
	order = 2.5,
	type = "toggle",
	set = function(i, v) self.db.char.stealth = v self:PlaceIcon() self:SummonPet() end,
	get = function(i) return self.db.char.stealth end,
   },
   chefhat = {
    name = "Chef's Hat",
	desc = "Summon cooking pet when using a chef's hat, must move forward to summon",
	order = 2.6,
	type = "toggle",
	set = function(i, v) self.db.char.chefhat = v self:SummonPet() end,
	get = function(i) return self.db.char.chefhat end,
   },
   mount = {
    name = "Mounts",
	desc = "Use different battlepets while on a mount",
	order = 3,
	type = "toggle",
	set = function(i, v) self.db.char.mount = v self:PlaceIcon() self:SummonPet() end,
	get = function(i) return self.db.char.mount end,
   },
   mountglobal = {
    name = "Use Global Mount List",
	order = 4,
	type = "toggle",
	set = function(i, v) self.db.char.useglobal = v self:PlaceIcon() self:SummonPet() end,
	get = function(i) return self.db.char.useglobal end
   },
   summonoptions = {
    name = "Summoning Options",
    order = 5,
    type = "select",
    style = "radio",
    values = { [""] = "Default", ["MINIONPET"] = "Hunter/Warlock Pet", ["EQUIPMENTSETS"] = "Equipment Sets", ["DRUIDFORMS"] = "Druid Forms" },
    set = function(i, v) if (v == "") then self:SetBattlepet(nil, true) else if (v == "DRUIDFORMS" and select(2,UnitClass("player")) ~= "DRUID") then return end self:SetBattlepet(v, true) end self:PlaceIcon() self:SummonPet() end,
    get = function(i) local pet = self:GetBattlepet(true) if (pet == "MINIONPET" or pet == "EQUIPMENTSETS" or pet == "DRUIDFORMS") then return pet else return "" end end,
    },
  },
 }
end

function BartrubySummonPet:UpgradeDB()
 if (self.db.char.ver < 1) then
  --self:Print("Upgrading database to version 1")
  --local tablesToUpgrade = { self.db.char.specs, self.db.char.sets, self.db.char.mounts }
  local battlepets = self.db.char.battlepets
  battlepets["default"] = self.db.char.battlepet
  self.db.char.battlepet = nil
  for i,v in pairs(self.db.char.specs) do
   battlepets.specs[i] = v.battlepet
   v.battlepet = nil
  end
  for i,v in pairs(self.db.char.sets) do
   battlepets.sets[i] = v.battlepet
   v.battlepet = nil
  end
  for i,v in pairs(self.db.char.mounts) do
   battlepets.mounts[i] = v.battlepet
   v.battlepet = nil
  end
  for i,v in pairs(self.db.char.pets) do
   battlepets.pets[i] = v.battlepet
   v.battlepet = nil
  end
  for i,v in pairs(self.db.char.druidforms) do
   battlepets.druidforms[i] = v.battlepet
   v.battlepet = nil
  end
  self.db.char.ver = 1
 end
end
