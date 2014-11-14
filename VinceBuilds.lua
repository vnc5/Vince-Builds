local function log(name, value)
	if SendVarToRover then
		SendVarToRover(name, value, 0)
	end
end

require "Window"
require "GameLib"
require "GroupLib"

local LoadingPixie = {
	cr = "ffffffff",
	strSprite = "CRB_ActionBarIconSprites:sprAS_Prompt_Resource2",
	loc = {
		fPoints = {0, 0, 1, 1},
		nOffsets = {0, 0, 0, 0}
	}
}
local WaitingPixie = {
	cr = "ffffffff",
	strSprite = "CRB_ActionBarIconSprites:sprAS_Prompt_Interrupt2",
	loc = {
		fPoints = {0, 0, 1, 1},
		nOffsets = {0, 0, 0, 0}
	}
}

local ModeLAS = 1
local ModeEquipment = 2


local VinceBuilds = {}
VinceBuilds.__index = VinceBuilds
function VinceBuilds:new(o)
	o = o or {}
	o.mode = ModeLAS
	o.defaultSettings = {
		savedEquipSlots = {
			[GameLib.CodeEnumEquippedItems.Chest] = true,
			[GameLib.CodeEnumEquippedItems.Feet] = true,
			[GameLib.CodeEnumEquippedItems.Gadget] = true,
			[GameLib.CodeEnumEquippedItems.Hands] = true,
			[GameLib.CodeEnumEquippedItems.Head] = true,
			[GameLib.CodeEnumEquippedItems.Implant] = true,
			[GameLib.CodeEnumEquippedItems.Legs] = true,
			[GameLib.CodeEnumEquippedItems.Shields] = true,
			[GameLib.CodeEnumEquippedItems.Shoulder] = true,
			[GameLib.CodeEnumEquippedItems.System] = true,
			[GameLib.CodeEnumEquippedItems.WeaponAttachment] = true,
			[GameLib.CodeEnumEquippedItems.WeaponPrimary] = true
		},
		equipments = {},
		las = {}
	}
	o.settings = TableUtil:Copy(o.defaultSettings)
    return setmetatable(o, self)
end

function VinceBuilds:Init()
    Apollo.RegisterAddon(self)
end

function VinceBuilds:OnLoad()
	self.onLoadDelayTimer = ApolloTimer.Create(.5, true, "OnLoadForReal", self)
end

function VinceBuilds:OnLoadForReal()
	local errorDialog = Apollo.GetAddon("ErrorDialog")
	local interfaceMenuList = Apollo.GetAddon("InterfaceMenuList")
	if errorDialog and errorDialog.wndReportBug and interfaceMenuList and interfaceMenuList.wndMain then
		self.onLoadDelayTimer:Stop()
	else
		return
	end
	
	self.xmlDoc = XmlDoc.CreateFromFile("VinceBuilds.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

	Apollo.RegisterEventHandler("PlayerEquippedItemChanged", "OnPlayerEquippedItemChanged", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnUnitEnteredCombat", self)
	Apollo.RegisterEventHandler("PlayerResurrected", "OnPlayerResurrected", self)
	Apollo.RegisterEventHandler("SpecChanged", "OnSpecChanged", self)
	
	Apollo.RegisterSlashCommand("vb", "OnSlashCommand", self)
	Apollo.RegisterSlashCommand("vincebuilds", "OnSlashCommand", self)

	-- Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "Vince Builds", {"ToggleVinceBuilds", "", "IconSprites:Icon_Windows_UI_CRB_Rival"})
end

function VinceBuilds:OnDocLoaded()
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "VinceBuilds", nil, self)
	self.wndConfig = Apollo.LoadForm(self.xmlDoc, "VinceBuildsForm", nil, self)

	self.nameInput = self.wndConfig:FindChild("EditBox")
	self.grid = self.wndConfig:FindChild("Grid")
	self.linkDropdown = self.wndConfig:FindChild("LinkDropdown")
	self.linkDropdownLabel = self.wndConfig:FindChild("LinkDropdownLabel")
	self.switch = self.wndConfig:FindChild("Switch")

	if self.settings.offsets then
		self.wndMain:SetAnchorOffsets(unpack(self.settings.offsets))
	end

	self.linkDropdown:AttachWindow(self.linkDropdown:FindChild("ChoiceContainer"))

	self:UpdateView()

--	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Vince Builds"})
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndConfig, strName = "Vince Builds Config", nSaveVersion = 2})
end

function VinceBuilds:OnVinceBuildsClick(wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	if wndControl ~= self.wndMain then
		return
	end

	self.wndMain:FindChild("Overlay"):SetSprite("CRB_ActionBarIconSprites:sprAS_ButtonPress")

	if eMouseButton == GameLib.CodeEnumInputMouse.Left then
		local container = self.wndMain:FindChild("ChoiceContainer")
		container:Show(true, true)
		container:DestroyChildren()
		for i, las in ipairs(self.settings.las) do
			local btn = Apollo.LoadForm(self.xmlDoc, "LASButton", container, self)
			btn:SetData(i)
			btn:FindChild("BtnText"):SetText(las.name)
		end

		local oLeft, oTop, oRight, oBottom = self.wndMain:GetAnchorOffsets()
		local pLeft, pTop, pRight, pBottom = self.wndMain:GetAnchorPoints()
		local height = container:ArrangeChildrenVert(0)
		local width = 125

		if oLeft > 0 then
			oLeft = -width
			oRight = 0
			pLeft = 0
			pRight = 0
		else
			oLeft = 0
			oRight = width
			pLeft = 1
			pRight = 1
		end
		if oTop > 0 then
			oTop = -height
			oBottom = 0
			pTop = 1
			pBottom = 1
		else
			oTop = 0
			oBottom = height
			pTop = 0
			pBottom = 0
		end

		container:SetAnchorOffsets(oLeft, oTop, oRight, oBottom)
		container:SetAnchorPoints(pLeft, pTop, pRight, pBottom)
	elseif eMouseButton == GameLib.CodeEnumInputMouse.Right then
		self.wndConfig:Show(not self.wndConfig:IsVisible(), true)
		self:FillGrid()
		self:SelectRow(1)
	end
end

function VinceBuilds:OnVinceBuildsMouseUp(wndHandler, wndControl)
	if wndControl ~= self.wndMain then
		return
	end
	self.wndMain:FindChild("Overlay"):SetSprite("CRB_ActionBarIconSprites:sprActionBar_GreenBorder")
end
function VinceBuilds:OnVinceBuildsMouseEnter(wndHandler, wndControl)
	if wndControl ~= self.wndMain then
		return
	end
	self.wndMain:FindChild("Overlay"):SetSprite("CRB_ActionBarIconSprites:sprActionBar_GreenBorder")
end

function VinceBuilds:OnVinceBuildsMouseExit(wndHandler, wndControl)
	if wndControl ~= self.wndMain then
		return
	end
	self.wndMain:FindChild("Overlay"):SetSprite("")
end

function VinceBuilds:GetBuildIndexByName(name, mode)
	local nameLower = name:lower()
	local tbl = self:GetModeTable(mode)

	for i = 1, #tbl do
		local build = tbl[i]
		if build.name:lower() == nameLower then
			return i
		end
	end
end

function VinceBuilds:ConcatArgsTillEnd(nonWhitespace, whitespace, index)
	local arg = {}
	for i = index, #nonWhitespace do
		table.insert(arg, nonWhitespace[i] .. (whitespace[i] or ""))
	end
	if #arg == 0 then
		return ""
	end
	return table.concat(arg)
end

-- no logical "or" in lua's pattern matching. holy shit
function VinceBuilds:GetArgs(args)
	local nonWhitespace = {}
	local whitespace = {}

	for nw in args:gmatch("%S+") do
		table.insert(nonWhitespace, nw)
	end
	for w in args:gmatch("%s+") do
		table.insert(whitespace, w)
	end

	return nonWhitespace, whitespace
end

function VinceBuilds:OnSlashCommand(slash, args)
	local nonWhitespace, whitespace = self:GetArgs(args)

	local cmd = nonWhitespace[1] and nonWhitespace[1]:lower() or ""
	local arg1 = self:ConcatArgsTillEnd(nonWhitespace, whitespace, 2)

	local arg1Lower = arg1:lower()

	if cmd == "loadequip" then
		local equip = self:GetBuildIndexByName(arg1Lower, ModeEquipment)
		if equip then
			self:LoadBuild(self:PrepareBuild(self.settings.equipments[equip]))
		else
			Print(("Equipment not found: %s"):format(arg1))
		end
	elseif cmd == "loadlas" then
		local las = self:GetBuildIndexByName(arg1Lower, ModeLAS)
		if las then
			self:LoadBuild(self:PrepareBuild(self.settings.las[las]))
		else
			Print(("LAS not found: %s"):format(arg1))
		end
	elseif cmd == "saveequip" then
		self:InsertBuild(arg1, ModeEquipment)
	elseif cmd == "savelas" then
		self:InsertBuild(arg1, ModeLAS)
--	elseif cmd == "link" then
--		local las = self:GetBuildIndexByName(arg1Lower, ModeLAS)
--		local equip = self:GetBuildIndexByName(arg2Lower, ModeEquipment)
--
--		if not las then
--			Print(("LAS not found: %s"):format(arg1))
--			return
--		end
--		if not equip then
--			Print(("Equipment not found: %s"):format(arg2))
--			return
--		end
--
--		self.settings.las[las].linkedEquipment = equip
	elseif cmd == "reset" then
		self.wndMain:SetAnchorOffsets(-31, -28, 31, 28)
	else
		Print(("/%s [ loadequip | loadlas | saveequip | savelas | reset ]"):format(slash))
	end
end

function VinceBuilds:ToggleVinceBuilds()

end

function VinceBuilds:PrepareBuild(build)
	local equip = build.linkedEquipment and self.settings.equipments[build.linkedEquipment]
	local prep = {
		actionSet = build.actionSet,
		equip = build.equip or (equip and equip.equip),
	}
	prep.costume = equip and equip.linkedCostume
	return prep
end

function VinceBuilds:OnLASBtn(wndControl)
	local las = self.settings.las[wndControl:GetData()]
	if not las then
		return
	end

	self:LoadBuild(self:PrepareBuild(las))
	self.wndMain:FindChild("ChoiceContainer"):Close()
end

function VinceBuilds:OnLinkDropdown()
	local row = self.grid:GetCurrentRow()
	if not row then
		return
	end

	local container = self.linkDropdown:FindChild("ChoiceContainer")
	local buttonList = container:FindChild("ButtonList")
	buttonList:DestroyChildren()

	if self.mode == ModeLAS then
		local btn = Apollo.LoadForm(self.xmlDoc, "DropdownBtn", buttonList, self)
		btn:SetData(0)
		btn:FindChild("BtnText"):SetText("")

		for i, equip in ipairs(self.settings.equipments) do
			local btn = Apollo.LoadForm(self.xmlDoc, "DropdownBtn", buttonList, self)
			btn:SetData(i)
			btn:FindChild("BtnText"):SetText(tostring(equip.name))
		end
	elseif self.mode == ModeEquipment then
		local btn = Apollo.LoadForm(self.xmlDoc, "DropdownBtn", buttonList, self)
		btn:SetData(-1)
		btn:FindChild("BtnText"):SetText("")

		local btn = Apollo.LoadForm(self.xmlDoc, "DropdownBtn", buttonList, self)
		btn:SetData(0)
		btn:FindChild("BtnText"):SetText("No Costume")

		for i = 1, GameLib.GetCostumeCount() do
			local btn = Apollo.LoadForm(self.xmlDoc, "DropdownBtn", buttonList, self)
			btn:SetData(i)
			btn:FindChild("BtnText"):SetText("Costume " .. i)
		end
	end

	local nLeft, nTop, nRight, nBottom = container:GetAnchorOffsets()
	container:SetAnchorOffsets(nLeft, nTop, nRight, nTop + buttonList:ArrangeChildrenVert(0) + 62)
end

function VinceBuilds:OnDropdownBtn(wndControl)
	local row = self.grid:GetCurrentRow()
	if not row then
		return
	end
	local build = self:GetModeTable()[row]
	local value = wndControl:GetData()

	if self.mode == ModeLAS then
		if value == 0 then
			build.linkedEquipment = nil
			self.linkDropdown:SetText("")
		else
			build.linkedEquipment = value
			self.linkDropdown:SetText(self.settings.equipments[value].name)
		end
	elseif self.mode == ModeEquipment then
		if value == -1 then
			build.linkedCostume = nil
			self.linkDropdown:SetText("")
		else
			build.linkedCostume = value
			self.linkDropdown:SetText(value == 0 and "No Costume" or "Costume " .. value)
		end
	end

	self.linkDropdown:FindChild("ChoiceContainer"):Close()
end

function VinceBuilds:GetModeTable(mode)
	mode = mode and mode or self.mode
	return mode == ModeLAS and self.settings.las or (mode == ModeEquipment and self.settings.equipments)
end

function VinceBuilds:OnGridItemClick(wndControl, wndHandler, iRow, iCol, eMouseButton)
	local build = self:GetModeTable()[iRow]
	if not build then
		return
	end
	if self.mode == ModeLAS then
		if build.linkedEquipment then
			self.linkDropdown:SetText(self.settings.equipments[build.linkedEquipment].name)
		else
			self.linkDropdown:SetText("")
		end
	elseif self.mode == ModeEquipment then
		if build.linkedCostume then
			self.linkDropdown:SetText(build.linkedCostume == 0 and "No Costume" or "Costume " .. build.linkedCostume)
		else
			self.linkDropdown:SetText("")
		end
	end
	self.nameInput:SetText(build.name)
	self.nameInput:ClearFocus()
end

function VinceBuilds:OnMoveUp()
	local row = self.grid:GetCurrentRow()
	if not row or row == 1 then
		return
	end

	local tbl = self:GetModeTable()

	local tmp = self.settings.las[row - 1]
	self.settings.las[row - 1] = self.settings.las[row]
	self.settings.las[row] = tmp

	self:FillGrid()
	self.grid:SetCurrentRow(row - 1)
end

function VinceBuilds:OnMoveDown()
	local row = self.grid:GetCurrentRow()
	local tbl = self:GetModeTable()
	if not row or row == #tbl then
		return
	end

	local tmp = self.settings.las[row]
	self.settings.las[row] = self.settings.las[row + 1]
	self.settings.las[row + 1] = tmp

	self:FillGrid()
	self.grid:SetCurrentRow(row + 1)
end

function VinceBuilds:FillGrid()
	self.grid:DeleteAll()
	if self.mode == ModeLAS then
		for i, las in ipairs(self.settings.las) do
			local row = self.grid:AddRow("")
			self.grid:SetCellText(row, 1, las.name)
		end
	elseif self.mode == ModeEquipment then
		for i, equip in ipairs(self.settings.equipments) do
			local row = self.grid:AddRow("")
			self.grid:SetCellText(row, 1, equip.name)
		end
	end
end

function VinceBuilds:OnSwitch()
	self.mode = (self.mode % 2) + 1
	self:UpdateView()
	self.nameInput:SetText("")
	self.nameInput:ClearFocus()
	self:FillGrid()
	self:SelectRow(1)
end

function VinceBuilds:UpdateView()
	if self.mode == ModeLAS then
		self.grid:SetColumnText(1, "LAS")
		self.switch:SetText("Equipment")
		self.switch:SetTooltip("Switch to Equipment")
		self.linkDropdownLabel:SetText("Link LAS with Equip:")
		self.linkDropdown:Enable(#self.settings.equipments > 0)
	elseif self.mode == ModeEquipment then
		self.grid:SetColumnText(1, "Equipment")
		self.switch:SetText("LAS")
		self.switch:SetTooltip("Switch to LAS")
		self.linkDropdownLabel:SetText("Link Equip with Costume:")
		self.linkDropdown:Enable(true)
	end
end

function VinceBuilds:OnSaveBuild()
	local newIndex = self:InsertBuild(self.nameInput:GetText(), self.mode)
	self:FillGrid()
	self:SelectRow(newIndex)
end

function VinceBuilds:InsertBuild(name, mode)
	local index = self:GetBuildIndexByName(name, mode)
	local tbl = self:GetModeTable(mode)

	if index then
		if mode == ModeLAS then
			tbl[index].actionSet = self:SaveActionSet()
		elseif mode == ModeEquipment then
			tbl[index].equip = self:SaveEquip()
		end
	else
		table.insert(tbl, {
			name = name,
			actionSet = mode == ModeLAS and self:SaveActionSet() or nil,
			equip = mode == ModeEquipment and self:SaveEquip() or nil
		})
	end

	return #tbl
end

function VinceBuilds:OnDelete()
	local row = self.grid:GetCurrentRow()
	if not row then
		return
	end

	local tbl = self:GetModeTable()
	if self.mode == ModeEquipment then
		for i, las in ipairs(self.settings.las) do
			if las.linkedEquipment == row then
				las.linkedEquipment = nil
			end
		end
	end
	table.remove(tbl, row)
	self.nameInput:SetText("")
	self:FillGrid()
	self:SelectRow(math.min(row, #tbl))
end

function VinceBuilds:SelectRow(row)
	self.grid:SetCurrentRow(row)
	self:OnGridItemClick(nil, nil, row)
end

function VinceBuilds:OnClose()
	if self.wndConfig then
		self.wndConfig:Show(false, true)
	end
end

function VinceBuilds:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	self.settings.offsets = {self.wndMain:GetAnchorOffsets()}

	return self.settings
end

function VinceBuilds:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	self.settings = tSavedData
end


function VinceBuilds:SaveBuild()
	local equip = self:SaveEquip()
	local actionSet = self:SaveActionSet()
	return {
		equip = equip,
		actionSet = actionSet
	}
end

function VinceBuilds:LoadBuild(build)
	self.isLoadingBuild = true
	self.isLoadingEquip = build.equip ~= nil and build.equip ~= false
	self.isLoadingActionSet = build.actionSet ~= nil and build.actionSet ~= false
	self.loadBuild = build

	self.wndMain:FindChild("Overlay"):DestroyAllPixies()

	local player = GameLib.GetPlayerUnit()
	if player:IsInCombat() or player:IsDead() then
		self.wndMain:FindChild("Overlay"):AddPixie(WaitingPixie)
	else
		self.wndMain:FindChild("Overlay"):AddPixie(LoadingPixie)

		if self.isLoadingEquip then
			if build.costume then
				GameLib.SetCostumeIndex(build.costume)
			end
			self:LoadEquip(build.equip)
		end
		if self.isLoadingActionSet then
			self:LoadActionSet(build.actionSet)
		end
	end
end

function VinceBuilds:SaveEquip()
	local items = {}
	for key, item in ipairs(GameLib.GetPlayerUnit():GetEquippedItems()) do
		-- if self.settings.savedEquipSlots[item:GetSlot()] then
			items[item:GetChatLinkString()] = true
		-- end
	end
	return items
end

function VinceBuilds:LoadEquip(equip)
	self.isLoadingEquip = true
	
	for key, item in ipairs(GameLib.GetPlayerUnit():GetInventoryItems()) do
		local itemInBag = item.itemInBag
		if itemInBag:IsEquippable() and equip[itemInBag:GetChatLinkString()] then
			GameLib.EquipBagItem(item.nBagSlot + 1)
			return
		end
	end
	
	self.isLoadingEquip = false
	
	self:UpdateFinishedLoadingBuild()
end

function VinceBuilds:SaveActionSet()
	local spec = AbilityBook.GetCurrentSpec()
	local abilities = {unpack(ActionSetLib.GetCurrentActionSet(), 1, 8)}
	local abilityTiers = self.ToMap(abilities, 1)
	for key, ability in ipairs(AbilityBook.GetAbilitiesList()) do
		if abilityTiers[ability.nId] then
			abilityTiers[ability.nId] = ability.nCurrentTier
		end
	end
	return {
		spec = spec,
		abilities = abilities,
		abilityTiers = abilityTiers
	}
end

function VinceBuilds:LoadActionSet(actionSet)
	self.isLoadingActionSet = true
	
	if actionSet.spec ~= AbilityBook.GetCurrentSpec() then
		AbilityBook.SetCurrentSpec(actionSet.spec)
		return
	end
	
	self.ResetSpellTiers()
	
	for abilityId, tier in pairs(actionSet.abilityTiers) do
		AbilityBook.UpdateSpellTier(abilityId, tier)
	end
	
	local currentActionSet = ActionSetLib.GetCurrentActionSet()
	for key, abilityId in ipairs(actionSet.abilities) do
		currentActionSet[key] = abilityId
	end
	local result = ActionSetLib.RequestActionSetChanges(currentActionSet) -- ActionSetLib.CodeEnumLimitedActionSetResult
	
	self.isLoadingActionSet = false
	
	self:UpdateFinishedLoadingBuild()
end

function VinceBuilds:UpdateFinishedLoadingBuild()
	local wasLoadingBuild = self.isLoadingBuild
	if self.isLoadingBuild and not self.isLoadingActionSet and not self.isLoadingEquip then
		self.isLoadingBuild = false
	end
	if wasLoadingBuild and not self.isLoadingBuild then
		self.wndMain:FindChild("Overlay"):DestroyAllPixies()
	end
end

function VinceBuilds:OnSpecChanged()
	if not self.isLoadingActionSet then
		return
	end
	
	self:LoadActionSet(self.loadBuild.actionSet)
end

function VinceBuilds:OnPlayerEquippedItemChanged()
	if not self.isLoadingEquip then
		return
	end
	
	self:LoadEquip(self.loadBuild.equip)
end

function VinceBuilds:OnUnitEnteredCombat(unit, bInCombat)
	if unit and unit:IsValid() and unit:IsThePlayer() and self.isLoadingBuild then
		if bInCombat then
			self.wndMain:FindChild("Overlay"):DestroyAllPixies()
			self.wndMain:FindChild("Overlay"):AddPixie(WaitingPixie)
		else
			self:LoadBuild(self.loadBuild)
		end
	end
end

function VinceBuilds:OnPlayerResurrected() -- still dead... troll game
	self.trollGarbageCollection = ApolloTimer.Create(1, false, "troll", {troll = function()
		if self.isLoadingBuild then
			self:LoadBuild(self.loadBuild)
		end
	end})
end

function VinceBuilds.ResetSpellTiers()
	for key, ability in ipairs(AbilityBook.GetAbilitiesList()) do
		if ability.bIsActive and ability.nCurrentTier > 1 then
			AbilityBook.UpdateSpellTier(ability.nId, 1)
		end
	end
end

function VinceBuilds.ToMap(list, defaultValue)
	local map = {}
	for key, value in ipairs(list) do
		map[value] = defaultValue or key
	end
	return map
end


local VinceBuildsInst = VinceBuilds:new()
VinceBuildsInst:Init()
