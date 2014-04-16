BartrubySummonPet = LibStub("AceAddon-3.0"):NewAddon("BartrubySummonPet", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

function BartrubySummonPet:OnInitialize()
 local defaults = {
  global = {
   enabled = true,
  },
  char = {
   enabled = true,
   battlepet = nil,
  },
 }

 self.db = LibStub("AceDB-3.0"):New("BartrubySummonPetDB", defaults, true)
 --self.db.RegisterCallback(self, "OnProfileChanged", "DBChange")
 --self.db.RegisterCallback(self, "OnProfileCopied", "DBChange")
 --self.db.RegisterCallback(self, "OnProfileReset", "DBChange")
 
 self:RegisterEvent("PET_JOURNAL_LIST_UPDATE", "PlaceIcon")
 -- May need to register UPDATE_SUMMONPETS_ACTION
 
 local frame = CreateFrame("Frame", nil, PetJournal)
 frame:SetPoint("TOPLEFT", PetJournal, "TOPRIGHT", 0, 0)
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
 frame:SetScript("OnShow", function(self) BartrubySummonPet:PlaceIcon() end)
 frame:SetScript("OnReceiveDrag", function(self) BartrubySummonPet:CheckCursor(nil) end)
 frame:SetScript("OnMouseUp", function(self, button) BartrubySummonPet:CheckCursor(button) end)
 frame:EnableMouse(true)
 frame:Show()
 self.bpFrame = frame 
end

function BartrubySummonPet:OnEnable()
 self:SecureHook("MoveForwardStart", "SummonPet")
 self:SecureHook("ToggleAutoRun", "SummonPet")
end

function BartrubySummonPet:OnDisable()
 self:UnregisterAllEvents()
 self.bpFrame:Hide()
end

function BartrubySummonPet:CheckCursor(button)
 --self:Print(GetCursorInfo())
 local type, id = GetCursorInfo()
 if (type == "battlepet") then
  self.db.char.battlepet = id
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
   self.db.char.battlepet = nil
  end
  self:PlaceIcon()
 end
end

function BartrubySummonPet:PlaceIcon()
 -- May need to add checks to see if they pet exists
 if (self.db.char.enabled) then
  self.bpFrame.enabled:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
 else
  self.bpFrame.enabled:SetTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
 end
 local id = self.db.char.battlepet
 if (not id) then
  self.bpFrame.texture:SetTexture("Interface\\ICONS\\Trade_Archaeology_TyrandesFavoriteDoll.blp");
  return 
 end
 local _, customName, _, _, _, displayID, _, name, icon, _, _, _, _, _, _, _, _, _ = C_PetJournal.GetPetInfoByPetID(id)
 --self:Print(C_PetJournal.GetPetInfoByPetID(id))
 self.bpFrame.texture:SetTexture(icon)
end

function BartrubySummonPet:SummonPet()
 -- Things to check for: combat, casting, stealth, mounted, eating/drinking
 if (not self.db.char.enabled) then return end
 if (InCombatLockdown()) then return end
 local id = self.db.char.battlepet
 local currentPet = C_PetJournal.GetSummonedPetGUID()
 if (currentPet == nil and id == nil) then return end
 if (currentPet ~= nil and id == nil) then C_PetJournal.SummonPetByGUID(currentPet) end
 if (currentPet ~= id and id ~= nil) then C_PetJournal.SummonPetByGUID(id) end
end