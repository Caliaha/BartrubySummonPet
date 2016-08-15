BartrubySummonPet = LibStub("AceAddon-3.0"):NewAddon("BartrubySummonPet", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

local EXCLUDEDZONES = {}
EXCLUDEDZONES["Proving Grounds"] = true

local EXCLUDEDPETS = {}

function BartrubySummonPet:OnInitialize()
 local defaults = {
  global = {
   enabled = true,
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
   mount = false,
   useglobal = false,
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
 self:RegisterEvent("PLAYER_LOGIN")
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
 
 if not PetJournal_OnLoad then
  UIParentLoadAddOn('Blizzard_Collections')
 end
 
 local frame = CreateFrame("Frame", nil, PetJournal)
 frame:SetPoint("TOPLEFT", PetJournal, "TOPRIGHT", self.db.global.x, self.db.global.y)
 frame:SetWidth(64)
 frame:SetHeight(64)
 --[[frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
      tile = true, tileSize = 16, edgeSize = 16, 
      insets = { left = 4, right = 4, top = 4, bottom = 4 }});
 frame:SetBackdropColor(1,1,1,1) ]]--
 frame.texture = frame:CreateTexture(nil, 'BACKGROUND')
 frame.texture:SetAllPoints(true)
 frame.texture:SetTexture("Interface\\ICONS\\Trade_Archaeology_TyrandesFavoriteDoll.blp")
 frame.enabled = frame:CreateTexture(nil, 'HIGH')
 frame.enabled:SetWidth(32)
 frame.enabled:SetHeight(32)
 frame.enabled:SetPoint("BOTTOMRIGHT")
 
 frame:RegisterEvent("OnReceiveDrag")
 frame:RegisterEvent("OnMouseUp")
 frame:SetScript("OnShow", function(self) BartrubySummonPet:PlaceIcon("show") end)
 frame:SetScript("OnReceiveDrag", function(self) BartrubySummonPet:CheckCursor(nil) end)
 frame:SetScript("OnMouseUp", function(self, button) BartrubySummonPet:CheckCursor(button); BartrubySummonPet:DragStop(self, button) end)
 frame:SetScript("OnMouseDown", function(self, button) BartrubySummonPet:DragStart(self, button) end)
 frame:SetScript("OnHide", function(self) BartrubySummonPet:PlaceIcon("hide") end)
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
              BartrubySummonPet.bpFrame:SetParent("PetJournal")
			  BartrubySummonPet.bpFrame:SetPoint("TOPLEFT", PetJournal, "TOPRIGHT", BartrubySummonPet.db.global.x, BartrubySummonPet.db.global.y)
			 end)
 end
end

function BartrubySummonPet:DBChange()
 if (RematchJournal and RematchJournal:IsVisible()) then
  self.bpFrame:SetPoint("TOPLEFT", RematchJournal, "TOPRIGHT", self.db.global.x, self.db.global.y)
 else
  self.bpFrame:SetPoint("TOPLEFT", PetJournal, "TOPRIGHT", self.db.global.x, self.db.global.y)
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
 
 if (command == "options") then
  InterfaceOptionsFrame_OpenToCategory("BartrubySummonPet")
 end

 self:Print("Commands are as following:")
 self:Print("reset -> Resets position of battlepet square")
 self:Print("spec -> Toggles summoning based on active specialization")
 self:Print("pets -> Toggles summoning based on current pet or demon (warlocks/hunters only)")
 self:Print("sets -> Toggles summoning based on current equipment set")
 self:Print("druid -> Toggles summoning based on current equipment set")
 self:Print("mount -> Toggles summoning based on current active mount")
 self:Print("global -> Toggles use of global mount list for current character")
 self:Print("pets and sets and druid are exclusive with each other, only one may be active")
 self:Print("Commands must be preceded by /bartrubysummonpet")
 
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
end

function BartrubySummonPet:CheckCursor(button)
 --self:Print(GetCursorInfo())
 local type, id = GetCursorInfo()
 if (type == "battlepet") then
  self:SetBattlepet(id)
  self:PlaceIcon()
  ClearCursor()
  return
 end
 if (button == "RightButton") then
  if (IsControlKeyDown()) then
   if (self.db.char.enabled) then
    self.db.char.enabled = false
   else
    self.db.char.enabled = true
   end
  else
   self:SetBattlepet(nil)
  end
  self:PlaceIcon()
 end
end

function BartrubySummonPet:PlaceIcon(register)
 if (register == "show") then
  self:RegisterEvent("PET_JOURNAL_LIST_UPDATE", "PlaceIcon") -- Might not be needed?
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "PlaceIcon")
  self:RegisterEvent("UNIT_PET", "PlaceIcon")
  self:RegisterEvent("EQUIPMENT_SETS_CHANGED", "PlaceIcon")
  self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "PlaceIcon")
  if (self.db.char.mounts) then self:RegisterEvent("UNIT_AURA", "PlaceIcon") end
 elseif (register == "hide") then
  self:UnregisterAllEvents()
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
 local noPetIcon = "Interface\\ICONS\\Trade_Archaeology_TyrandesFavoriteDoll.blp"

 
 
 if (not id) then
  self.bpFrame.texture:SetTexture(noPetIcon);
  return 
 end
 
 local _, _, _, _, _, _, _, _, icon, _, _, _, _, _, _, _, _, _ = C_PetJournal.GetPetInfoByPetID(id)
 self.bpFrame.texture:SetTexture(icon)
end

function BartrubySummonPet:GetBattlepet(noFooling)
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
 
 if (not noFooling and id) then
  battlepetName = select(8, C_PetJournal.GetPetInfoByPetID(id))
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
   self.db.char.battlepets.default = id
  end
 end
end

function BartrubySummonPet:SummonPet()
 -- Things to check for: other pets (guild, argent tourney)
 if (not self.db.char.enabled) then return end
 if (InCombatLockdown()) then return end
 if (IsStealthed()) then return end
 if (EXCLUDEDZONES[GetRealZoneText()]) then return end
 local id = self:GetBattlepet()
 
 local currentPet = C_PetJournal.GetSummonedPetGUID()
 if (currentPet == nil and id == nil) then return end -- No pet out and no pet to summon; do nothing
 if (currentPet ~= nil and id == nil) then C_PetJournal.SummonPetByGUID(currentPet) end -- Pet out but should be dismissed; dismiss current pet
 if (currentPet ~= id and id ~= nil) then C_PetJournal.SummonPetByGUID(id) end -- No or incorrect pet is out; summon
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

function BartrubySummonPet:DragStop(frame, button)
 if (button == "LeftButton" and frame.isMoving == true) then
  frame.isMoving = false
  --self.db.global.x = frame:GetLeft()
  --self.db.global.y = frame:GetTop()
  local _, _, _, x, y = frame:GetPoint()
  frame:StopMovingOrSizing()
  --self:Print(x, y)
  local xDelta = x - xB
  local yDelta = y - yB
  --self:Print(xDelta, yDelta)
  self.db.global.x = xDelta + self.db.global.x
  self.db.global.y = yDelta + self.db.global.y
  --self:Print(self.db.global.x, self.db.global.y)
  self:DBChange()
 end
end

function BartrubySummonPet:GetCurrentlyEquippedSet()
 for i=1, GetNumEquipmentSets() do
  local name, _, _, isEquipped, _, _, _, _, _ = GetEquipmentSetInfo(i)
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
    set = function(i, v) self.db.char.enabled = v self:PlaceIcon() end,
    get = function(i) return self.db.char.enabled end
   },
   specialization = {
    name = "Specializations",
	desc = "Use different battlepets for each spec",
	order = 2,
	type = "toggle",
	set = function(i, v) self.db.char.multispecs = v self:PlaceIcon() end,
	get = function(i) return self.db.char.multispecs end,
   },
   mount = {
    name = "Mounts",
	desc = "Use different battlepets while on a mount",
	order = 3,
	type = "toggle",
	set = function(i, v) self.db.char.mount = v self:PlaceIcon() end,
	get = function(i) return self.db.char.mount end,
   },
   mountglobal = {
    name = "Use Global Mount List",
	order = 4,
	type = "toggle",
	set = function(i, v) self.db.char.useglobal = v self:PlaceIcon() end,
	get = function(i) return self.db.char.useglobal end
   },
   summonoptions = {
    name = "Summoning Options",
    order = 5,
    type = "select",
    style = "radio",
    values = { [""] = "Default", ["MINIONPET"] = "Hunter/Warlock Pet", ["EQUIPMENTSETS"] = "Equipment Sets", ["DRUIDFORMS"] = "Druid Forms" },
    set = function(i, v) if (v == "") then self:SetBattlepet(nil, true) else if (v == "DRUIDFORMS" and select(2,UnitClass("player")) ~= "DRUID") then return end self:SetBattlepet(v, true) end end,
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