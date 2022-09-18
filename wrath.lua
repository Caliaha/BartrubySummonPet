BartrubySummonPet = LibStub("AceAddon-3.0"):NewAddon("BartrubySummonPet", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

local LQT = LibStub("LibQTip-1.0")

local NO_PET_ICON = "Interface\\ICONS\\spell_nature_spiritwolf.blp"
local RANDOM_PET_ICON = "Interface\\ICONS\\spell_Shaman_Measuredinsight.blp"
local EXCLUDEDZONES = {}
EXCLUDEDZONES["Proving Grounds"] = true -- This can probably be removed, I'm fairly sure zones are localized

function BartrubySummonPet:OnInitialize()
	local defaults = {
		global = {
			enabled = true,
			tooltip = true,
			x = 0,
			y = 0,
		},
		char = {
			enabled = true,
			battlepet = nil,
			multispecs = false,
			stealth = false,
			ver = 1,
			battlepets = {
				default = nil,
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
		},
	}

	self.db = LibStub("AceDB-3.0"):New("BartrubySummonPetDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "DBChange")
	self.db.RegisterCallback(self, "OnProfileCopied", "DBChange")
	self.db.RegisterCallback(self, "OnProfileReset", "DBChange")
 
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("BartrubySummonPet", self:GenerateOptions())
	self.configFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("BartrubySummonPet", "BartrubySummonPet")

	self:RegisterChatCommand("bartrubysummonpet","HandleIt")
	self:RegisterChatCommand("bsp","HandleIt")
	self:RegisterEvent("PLAYER_LOGIN")
	self:RegisterEvent("UPDATE_STEALTH", "StealthStuff")
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
 
	local frame = CreateFrame("Frame", nil, PetPaperDollFrameCompanionFrame)
	frame:SetPoint("TOPLEFT", PetPaperDollFrameCompanionFrame, "TOPRIGHT", self.db.global.x, self.db.global.y)
	frame:SetWidth(64)
	frame:SetHeight(64)
	frame.texture = frame:CreateTexture(nil, 'BACKGROUND')
	frame.texture:SetAllPoints(true)
	frame.texture:SetTexture(NO_PET_ICON)
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

										tooltip:AddLine("Right-click to clear icon and dismiss pet")
										tooltip:AddLine("Control Right-click to disable/enable this addon for this character")
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
end

function BartrubySummonPet:DBChange()
	self.bpFrame:ClearAllPoints()
	self.bpFrame:SetPoint("TOPLEFT", PetPaperDollFrameCompanionFrame, "TOPRIGHT", self.db.global.x, self.db.global.y)
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

	if (command == "random") then
		if (self:GetBattlepet(true) == "RANDOMALL") then
			self:SetBattlepet(nil, true)
			self:Print("Will no longer summon random battle pets")
		else
			self:SetBattlepet("RANDOMALL", true)
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
		self:Print("druid -> Toggles summoning based on current equipment set")
		self:Print("random -> Toggles summoning of random pet")
		self:Print("pets and sets and druid are exclusive with each other, only one may be active")
		self:Print("Commands must be preceded by /bartrubysummonpet or /bsp")
		return
	end

	if (self:GetBattlepet(true) == "DRUIDFORMS") then
		self:Print("Currently set to summon battlepets based on currently active druid form")
	end

	if (self:GetBattlepet(true) == "MINIONPET") then
		self:Print("Currently set to summon battlepets based on currently active pet")
	end

	if (self.db.char.multispecs) then
		self:Print("Currently set to summon battlepets based on currently active spec")
	end

	InterfaceOptionsFrame_OpenToCategory("BartrubySummonPet")
	InterfaceOptionsFrame_OpenToCategory("BartrubySummonPet")
end

function BartrubySummonPet:CheckCursor(button)
	local type, id = GetCursorInfo()

	if (type == "companion") then
		local creatureID, creatureName = GetCompanionInfo("CRITTER", id)
		self:SetBattlepet(id)
		self:PlaceIcon()
		self:SummonPet()
		ClearCursor()
		return
	end
	if (button == "RightButton") then
		if (IsControlKeyDown() and not IsAltKeyDown()) then
			if (self.db.char.enabled) then
				self.db.char.enabled = false
			else
				self.db.char.enabled = true
			end
		elseif (IsAltKeyDown() and not IsControlKeyDown()) then
			if (self:GetBattlepet(true) == "RANDOMALL") then
				self:SetBattlepet(nil)
			else
				self:SetBattlepet("RANDOMALL")
			end
		elseif (not IsShiftKeyDown()) then
			self:SetBattlepet(nil)
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
		self:RegisterEvent("UNIT_PET", "PlaceIcon")
		self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "PlaceIcon")
		self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "PlaceIcon")
	elseif (register == "hide") then
		self:UnregisterEvent("UNIT_PET")
		self:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
		self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM")
	end

	if (not self.bpFrame:IsVisible()) then return end -- If we can't be seen then don't do anything
 
 -- May need to add checks to see if the pet exists
	if (self.db.char.enabled) then
		self.bpFrame.enabled:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	else
		self.bpFrame.enabled:SetTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	end
 
 local id = self:GetBattlepet()
 
	if (not id) then
		self.bpFrame.texture:SetTexture(NO_PET_ICON);
		return
	elseif (id == "RANDOMALL") then
		self.bpFrame.texture:SetTexture(RANDOM_PET_ICON)
		return
	end
 
	local _, _, _, icon = self:GetIDFromCreatureID(id)
	self.bpFrame.texture:SetTexture(icon)
end

function BartrubySummonPet:GetCurrentSpecialization()
	if GetActiveTalentGroup() == 2 then
		return "SECONDARY"
	end
	return "PRIMARY"
end

function BartrubySummonPet:GetBattlepet(noFooling)
	local id = nil
	if (self.db.char.multispecs) then
		local activeSpec = self:GetCurrentSpecialization()
		id = self.db.char.battlepets.specs[activeSpec]
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
	elseif (id and not noFooling) then
		id, creatureName = GetCompanionInfo("CRITTER", id)
		battlepetName = creatureName
	end

	if (self.db.char.multispecs) then
		local activeSpec = self:GetCurrentSpecialization()
		battlepet = self.db.char.battlepets.specs[activeSpec]
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
	elseif (battlepet == "DRUIDFORMS" and not noFooling) then
		local form = GetShapeshiftForm()
		if (form == nil) then form = 0 end
		self.db.char.battlepets.druidforms[form] = id
	else
		if (self.db.char.multispecs) then
			local activeSpec = self:GetCurrentSpecialization()
			self.db.char.battlepets.specs[activeSpec] = id
			if (battlepetName ~= "NO PET") then
				self:Print("Set",battlepetName,"for",activeSpec,"specialization.")
			end
		else
			self.db.char.battlepets.default = id
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
	if (not self.db.char.enabled or InCombatLockdown() or IsMounted() or UnitIsDeadOrGhost("player") or IsStealthed() or IsFalling() or EXCLUDEDZONES[GetRealZoneText()]) then return end
	local id = nil
	local creatureID = self:GetBattlepet()
	local currentPet = self:GetCurrentSummonedPet()

	if (creatureID == "RANDOMALL") then
		if (not currentPet) then
			local numCompanions = GetNumCompanions("CRITTER")
			if numCompanions > 0 then
				CallCompanion("CRITTER", math.random(1, numCompanions))
			end
		end
		return
	end

	if creatureID then
		id = self:GetIDFromCreatureID(creatureID)
	end
 
	if (currentPet == false and id == nil) then return end -- No pet out and no pet to summon; do nothing
	if (currentPet ~= false and id == nil) then DismissCompanion("CRITTER") end -- Pet out but should be dismissed; dismiss current pet
	if (currentPet ~= id and id ~= nil) then CallCompanion("CRITTER", id) end -- No or incorrect pet is out; summon
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
	end
end

function BartrubySummonPet:StealthStuff()
	if (not self.db.char.stealth) then return end

	if (IsStealthed()) then
		if (InCombatLockdown()) then return end -- Can't dismiss pet in combat
		local currentPet = self:GetCurrentSummonedPet()
		if (not currentPet) then return end -- No pet to dismiss
		DismissCompanion("CRITTER")
	else
		self:SummonPet()
	end
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
   summonoptions = {
    name = "Summoning Options",
    order = 5,
    type = "select",
    style = "radio",
    values = { [""] = "Default", ["MINIONPET"] = "Hunter/Warlock Pet", ["DRUIDFORMS"] = "Druid Forms" },
    set = function(i, v) if (v == "") then self:SetBattlepet(nil, true) else if (v == "DRUIDFORMS" and select(2,UnitClass("player")) ~= "DRUID") then return end self:SetBattlepet(v, true) end self:PlaceIcon() self:SummonPet() end,
    get = function(i) local pet = self:GetBattlepet(true) if (pet == "MINIONPET" or pet == "DRUIDFORMS") then return pet else return "" end end,
    },
  },
 }
end
