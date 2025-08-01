-- This module is WIP, expect all code to be awful
local L, LoaderPublic, db
do
	local _, tbl = ...
	L = tbl.API:GetLocale("BigWigs")
	LoaderPublic = tbl.loaderPublic

	local defaultVoice = "English: Amy"
	do
		local locale = GetLocale()
		if locale ~= "enUS" then
			defaultVoice = ("%s: Default (Female)"):format(locale)
		end
	end

	local defaults = {
		autoSlotKeystone = true,
		countVoice = defaultVoice,
		countBegin = 5,
		autoShowZoneIn = true,
		autoShowEndOfRun = true,
		hideFromGuild = false,
	}
	db = LoaderPublic.db:RegisterNamespace("MythicPlus", {profile = defaults})
	for k, v in next, db do
		local defaultType = type(defaults[k])
		if defaultType == "nil" then
			db.profile[k] = nil
		elseif type(v) ~= defaultType then
			db.profile[k] = defaults[k]
		end
	end
	if db.profile.countBegin < 3 or db.profile.countBegin > 9 then
		db.profile.countBegin = defaults.countBegin
	end
end

local LibKeystone = LibStub("LibKeystone")
if db.profile.hideFromGuild then
	LibKeystone.SetGuildHidden(true)
end
local LibSpec = LibStub("LibSpecialization")

local guildList, partyList = {}, {}
local WIDTH_NAME, WIDTH_LEVEL, WIDTH_MAP, WIDTH_RATING = 150, 24, 66, 42

local GetMapUIInfo, GetRealZoneText = C_ChallengeMode.GetMapUIInfo, GetRealZoneText

local specs = {}
do
	local function addToTable(specID, _, _, playerName)
		specs[playerName] = specID
	end
	LibSpec.RegisterGroup(specs, addToTable)
	LibSpec.RegisterGuild(specs, addToTable)
end

local roleIcons = {
	TANK = "|TInterface\\AddOns\\BigWigs\\Media\\Icons\\Menus\\Role_Tank:16:16|t",
	HEALER = "|TInterface\\AddOns\\BigWigs\\Media\\Icons\\Menus\\Role_Healer:16:16|t",
	DAMAGER = "|TInterface\\AddOns\\BigWigs\\Media\\Icons\\Menus\\Role_Damage:16:16|t",
}
local hiddenIcon = "|TInterface\\AddOns\\BigWigs\\Media\\Icons\\Menus\\Private:16:16|t"
local dungeonNames = {
	[500] = L.keystoneShortName_TheRookery, -- ROOK
	[504] = L.keystoneShortName_DarkflameCleft, -- DFC
	[499] = L.keystoneShortName_PrioryOfTheSacredFlame, -- PRIORY
	[506] = L.keystoneShortName_CinderbrewMeadery, -- BREW
	[525] = L.keystoneShortName_OperationFloodgate, -- FLOOD
	[382] = L.keystoneShortName_TheaterOfPain, -- TOP
	[247] = L.keystoneShortName_TheMotherlode, -- ML
	[370] = L.keystoneShortName_OperationMechagonWorkshop, -- WORK

	[542] = L.keystoneShortName_EcoDomeAldani, -- ALDANI
	[378] = L.keystoneShortName_HallsOfAtonement, -- HOA
	[503] = L.keystoneShortName_AraKaraCityOfEchoes, -- ARAK
	[392] = L.keystoneShortName_TazaveshSoleahsGambit, -- GAMBIT
	[391] = L.keystoneShortName_TazaveshStreetsOfWonder, -- STREET
	[505] = L.keystoneShortName_TheDawnbreaker, -- DAWN
}
local teleports = LoaderPublic.isTestBuild and {
	[2830] = 1237215, -- Eco-Dome Al'dani
	[2287] = 354465, -- Halls of Atonement
	[2660] = 445417, -- Ara-Kara, City of Echoes
	[2441] = 367416, -- Tazavesh, the Veiled Market
	[2662] = 445414, -- The Dawnbreaker
	[2649] = 445444, -- Priory of the Sacred Flame
	[2773] = 1216786, -- Operation: Floodgate
} or {
	[1594] = UnitFactionGroup("player") == "Alliance" and 467553 or 467555, -- The MOTHERLODE!!
	[2097] = 373274, -- Operation: Mechagon
	[2293] = 354467, -- Theater of Pain
	[2648] = 445443, -- The Rookery
	[2649] = 445444, -- Priory of the Sacred Flame
	[2651] = 445441, -- Darkflame Cleft
	[2661] = 445440, -- Cinderbrew Meadery
	[2773] = 1216786, -- Operation: Floodgate
}
local tempTranslate = { -- XXX remove in 11.2
	[247] = 1594, -- The MOTHERLODE!!
	[370] = 2097, -- Operation: Mechagon
	[382] = 2293, -- Theater of Pain
	[500] = 2648, -- The Rookery
	[499] = 2649, -- Priory of the Sacred Flame
	[504] = 2651, -- Darkflame Cleft
	[506] = 2661, -- Cinderbrew Meadery
	[525] = 2773, -- Operation: Floodgate
}
local cellsCurrentlyShowing = {}
local cellsAvailable = {}
local RequestData
local prevTab = 1

local mainPanel = CreateFrame("Frame", nil, UIParent, "PortraitFrameTemplate")
mainPanel:Hide()
mainPanel:SetSize(350, 320)
mainPanel:SetPoint("LEFT", 15, 0)
mainPanel:SetFrameStrata("DIALOG")
mainPanel:SetMovable(true)
mainPanel:EnableMouse(true)
mainPanel:RegisterForDrag("LeftButton")
mainPanel:SetTitle(L.keystoneTitle)
mainPanel:SetTitleOffsets(0, 0)
mainPanel:SetBorder("HeldBagLayout")
mainPanel:SetPortraitTextureSizeAndOffset(38, -5, 0)
mainPanel:SetPortraitTextureRaw("Interface\\AddOns\\BigWigs\\Media\\Icons\\minimap_raid.tga")
mainPanel:SetScript("OnDragStart", function(self)
	if prevTab == 2 and InCombatLockdown() then
		LoaderPublic.Print(L.youAreInCombat)
		return
	end
	self:StartMoving()
end)
mainPanel:SetScript("OnDragStop", function(self)
	if prevTab == 2 and InCombatLockdown() then
		LoaderPublic.Print(L.youAreInCombat)
		return
	end
	self:StopMovingOrSizing()
end)

local UpdateMyKeystone
do
	local GetMaxPlayerLevel = GetMaxPlayerLevel
	local GetWeeklyResetStartTime = C_DateAndTime.GetWeeklyResetStartTime
	local GetOwnedKeystoneLevel, GetOwnedKeystoneChallengeMapID, GetCurrentSeason = C_MythicPlus.GetOwnedKeystoneLevel, C_MythicPlus.GetOwnedKeystoneChallengeMapID, C_MythicPlus.GetCurrentSeason
	local GetPlayerMythicPlusRatingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary
	local GetRealmName = GetRealmName

	local myKeyLevel, myKeyMap, myRating = 0, 0, 0
	UpdateMyKeystone = function(self, event, id, isReloadingUi)
		if event == "PLAYER_ENTERING_WORLD" then
			if id or isReloadingUi then
				if SLASH_KEYSTONE3 then
					SLASH_KEYSTONE3 = nil
				end
			end
			if LoaderPublic.UnitLevel("player") ~= GetMaxPlayerLevel() then
				return
			elseif not id and not isReloadingUi then -- Don't show when logging in (arg1) or reloading UI (arg2)
				LoaderPublic.CTimerAfter(0, function() -- Difficulty info isn't accurate until 1 frame after PEW
					local _, _, diffID = LoaderPublic.GetInstanceInfo()
					local season = GetCurrentSeason()
					if diffID == 23 and season > 0 and db.profile.autoShowZoneIn then
						RequestData()
					end
				end)
			end
		elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and id ~= 3 and id ~= 49 then -- 3 = Gossip (key downgrade NPC), 49 = WeeklyRewards (vault)
			return
		end

		if type(BigWigs3DB.myKeystones) ~= "table" then
			BigWigs3DB.myKeystones = {}
		end
		local resetStart = GetWeeklyResetStartTime()
		if type(BigWigs3DB.prevWeeklyReset) ~= "number" or resetStart ~= BigWigs3DB.prevWeeklyReset then
			BigWigs3DB.prevWeeklyReset = resetStart
			BigWigs3DB.myKeystones = {}
		end

		local keyLevel = GetOwnedKeystoneLevel()
		if type(keyLevel) == "number" then
			myKeyLevel = keyLevel
		end
		-- Keystone instance ID
		local keyChallengeMapID = GetOwnedKeystoneChallengeMapID()
		if type(keyChallengeMapID) == "number" then
			myKeyMap = keyChallengeMapID
		end
		-- M+ rating
		local playerRatingSummary = GetPlayerMythicPlusRatingSummary("player")
		if type(playerRatingSummary) == "table" and type(playerRatingSummary.currentSeasonScore) == "number" then
			myRating = playerRatingSummary.currentSeasonScore
		end

		local guid = LoaderPublic.UnitGUID("player")
		local name = LoaderPublic.UnitName("player")
		local realm = GetRealmName()
		BigWigs3DB.myKeystones[guid] = {
			keyLevel = myKeyLevel,
			keyMap = myKeyMap,
			playerRating = myRating,
			specId = specs[name] or 0,
			name = name,
			realm = realm,
		}
	end
	mainPanel:SetScript("OnEvent", UpdateMyKeystone)
end
-- If only PLAYER_LOGOUT would work for keystone info, sigh :(
mainPanel:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
mainPanel:RegisterEvent("PLAYER_ENTERING_WORLD")

local tab1 = CreateFrame("Button", nil, mainPanel, "PanelTabButtonTemplate")
tab1:SetSize(50, 26)
tab1:SetPoint("BOTTOMLEFT", 10, -25)
tab1.Text:SetText(L.keystoneTabOnline)
tab1:UnregisterAllEvents() -- Remove events registered by the template
tab1:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
do
	local HasSlottedKeystone, SlotKeystone = C_ChallengeMode.HasSlottedKeystone, C_ChallengeMode.SlotKeystone
	local GetOwnedKeystoneMapID = C_MythicPlus.GetOwnedKeystoneMapID
	local GetContainerNumSlots, GetContainerItemLink, PickupContainerItem = C_Container.GetContainerNumSlots, C_Container.GetContainerItemLink, C_Container.PickupContainerItem
	tab1:SetScript("OnEvent", function()
		if db.profile.autoSlotKeystone and not HasSlottedKeystone() then
			local _, _, _, _, _, _, _, instanceID = LoaderPublic.GetInstanceInfo()
			if GetOwnedKeystoneMapID() == instanceID then
				for currentBag = 0, 4 do -- 0=Backpack, 1/2/3/4=Bags
					local slots = GetContainerNumSlots(currentBag)
					for currentSlot = 1, slots do
						local itemLink = GetContainerItemLink(currentBag, currentSlot)
						if itemLink and itemLink:find("Hkeystone", nil, true) then
							PickupContainerItem(currentBag, currentSlot)
							SlotKeystone()
							LoaderPublic.Print(L.keystoneAutoSlotMessage:format(itemLink))
						end
					end
				end
			end
		end
	end)
end

local tab2 = CreateFrame("Button", nil, mainPanel, "PanelTabButtonTemplate")
tab2:SetSize(50, 26)
tab2:SetPoint("LEFT", tab1, "RIGHT", 4, 0)
tab2.Text:SetText(L.keystoneTabTeleports)
tab2:UnregisterAllEvents() -- Remove events registered by the template
tab2:RegisterEvent("CHALLENGE_MODE_RESET")
do
	local GetActiveKeystoneInfo, GetActiveChallengeMapID = C_ChallengeMode.GetActiveKeystoneInfo, C_ChallengeMode.GetActiveChallengeMapID
	tab2:SetScript("OnEvent", function(self, event)
		if event == "CHALLENGE_MODE_START" then
			local keyLevel = GetActiveKeystoneInfo()
			local challengeMapID = GetActiveChallengeMapID()
			LoaderPublic:SendMessage("BigWigs_StartCountdown", self, nil, "mythicplus", 9, nil, db.profile.countVoice, 9, nil, db.profile.countBegin)
			if keyLevel and keyLevel > 0 then
				LoaderPublic:SendMessage("BigWigs_StartBar", self, nil, L.keystoneStartBar:format(dungeonNames[challengeMapID] or "?", keyLevel), 9, 525134) -- 525134 = inv_relics_hourglass
			else
				LoaderPublic:SendMessage("BigWigs_StartBar", self, nil, L.keystoneModuleName, 9, 525134) -- 525134 = inv_relics_hourglass
			end
			LoaderPublic.CTimerAfter(9, function()
				local challengeMapName, _, _, icon = GetMapUIInfo(challengeMapID)
				LoaderPublic:SendMessage("BigWigs_Message", self, nil, L.keystoneStartBar:format(challengeMapName, keyLevel), "cyan", icon)
				LoaderPublic.Print(L.keystoneStartMessage:format(challengeMapName, keyLevel))
			end)
		else
			local _, _, diffID = LoaderPublic.GetInstanceInfo()
			if diffID == 8 then
				TimerTracker:UnregisterEvent("START_TIMER")
				LoaderPublic.CTimerAfter(1, function()
					TimerTracker:RegisterEvent("START_TIMER")
					self:UnregisterEvent("CHALLENGE_MODE_START")
				end)
				self:RegisterEvent("CHALLENGE_MODE_START")
			end
		end
	end)
end

local tab3 = CreateFrame("Button", nil, mainPanel, "PanelTabButtonTemplate")
tab3:SetSize(50, 26)
tab3:SetPoint("LEFT", tab2, "RIGHT", 4, 0)
tab3.Text:SetText(L.keystoneTabAlts)
tab3:UnregisterAllEvents() -- Remove events registered by the template
tab3:RegisterEvent("CHALLENGE_MODE_COMPLETED")
tab3:SetScript("OnEvent", function()
	if db.profile.autoShowEndOfRun then
		LoaderPublic.CTimerAfter(2, RequestData)
	end
end)

local tab4 = CreateFrame("Button", nil, mainPanel, "PanelTabButtonTemplate")
tab4:SetSize(50, 26)
tab4:SetPoint("LEFT", tab3, "RIGHT", 4, 0)
tab4.Text:SetText(L.keystoneTabHistory)
tab4:UnregisterAllEvents() -- Remove events registered by the template

local function WipeCells()
	for cell in next, cellsCurrentlyShowing do
		cell:Hide()
		cell.tooltip = nil
		if cell.isGlowing then
			cell.isGlowing = nil
			LibStub("LibCustomGlow-1.0").PixelGlow_Stop(cell)
		end
		cell:ClearAllPoints()
		cellsAvailable[#cellsAvailable+1] = cell
	end
	cellsCurrentlyShowing = {}
end

local teleportButtons = {}
mainPanel.CloseButton:SetScript("OnClick", function()
	if prevTab == 2 then
		if InCombatLockdown() then
			LoaderPublic.Print(L.youAreInCombat)
			return
		else
			prevTab = 1
			teleportButtons[1]:ClearAllPoints()
			teleportButtons[1]:SetScript("OnUpdate", nil)
			for i = 1, #teleportButtons do
				teleportButtons[i]:SetParent(nil)
				teleportButtons[i]:Hide()
			end
		end
	end
	WipeCells()
	mainPanel:Hide()
end)
mainPanel.CloseButton:RegisterEvent("PLAYER_LEAVING_WORLD")
mainPanel.CloseButton:SetScript("OnEvent", function(self)
	if mainPanel:IsShown() then
		self:Click()
	end
end)

local scrollArea = CreateFrame("ScrollFrame", nil, mainPanel, "ScrollFrameTemplate")
scrollArea:SetPoint("TOPLEFT", mainPanel, "TOPLEFT", 8, -30)
scrollArea:SetPoint("BOTTOMRIGHT", mainPanel, "BOTTOMRIGHT", -24, 5)

local scrollChild = CreateFrame("Frame", nil, scrollArea)
scrollArea:SetScrollChild(scrollChild)
scrollChild:SetSize(scrollArea:GetWidth(), 320)
scrollChild:SetPoint("LEFT")

local partyHeader = scrollChild:CreateFontString(nil, nil, "GameFontNormalLarge")
partyHeader:SetPoint("TOP", scrollChild, "TOP", 0, -0)
partyHeader:SetText(L.keystoneHeaderParty)
partyHeader:SetJustifyH("CENTER")

local partyRefreshButton = CreateFrame("Button", nil, scrollChild)
partyRefreshButton:SetSize(20, 20)
partyRefreshButton:SetPoint("LEFT", partyHeader, "RIGHT", 5, 0)
partyRefreshButton:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
partyRefreshButton:SetPushedTexture("Interface\\Buttons\\UI-RefreshButton-Down")
partyRefreshButton:SetHighlightTexture("Interface\\Buttons\\UI-RefreshButton")
partyRefreshButton:SetScript("OnClick", function()
	partyList = {}
	LibKeystone.Request("PARTY")
end)
partyRefreshButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(L.keystoneRefreshParty)
	GameTooltip:Show()
end)
partyRefreshButton:SetScript("OnLeave", GameTooltip_Hide)

local guildHeader = scrollChild:CreateFontString(nil, nil, "GameFontNormalLarge")
guildHeader:SetText(L.keystoneHeaderGuild)
guildHeader:SetJustifyH("CENTER")

-- Refresh button for Guild section
local guildRefreshButton = CreateFrame("Button", nil, scrollChild)
guildRefreshButton:SetSize(20, 20)
guildRefreshButton:SetPoint("LEFT", guildHeader, "RIGHT", 5, 0)
guildRefreshButton:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
guildRefreshButton:SetPushedTexture("Interface\\Buttons\\UI-RefreshButton-Down")
guildRefreshButton:SetHighlightTexture("Interface\\Buttons\\UI-RefreshButton")
guildRefreshButton:SetScript("OnClick", function()
	guildList = {}
	LibSpec.RequestGuildSpecialization()
	C_Timer.After(0.1, function() LibKeystone.Request("GUILD") end)
end)
guildRefreshButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(L.keystoneRefreshGuild)
	GameTooltip:Show()
end)
guildRefreshButton:SetScript("OnLeave", GameTooltip_Hide)

local OnEnterShowTooltip = function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(self.tooltip)
	GameTooltip:Show()
end
local function CreateCell()
	local cell = cellsAvailable[#cellsAvailable]
	if cell then
		cellsAvailable[#cellsAvailable] = nil
		cell:Show()
		cellsCurrentlyShowing[cell] = true
		return cell
	else
		cell = CreateFrame("Frame", nil, scrollChild)
		cell:SetSize(20, 20)
		cell:SetScript("OnEnter", OnEnterShowTooltip)
		cell:SetScript("OnLeave", GameTooltip_Hide)

		cell.text = cell:CreateFontString(nil, nil, "GameFontNormal")
		cell.text:SetAllPoints(cell)
		cell.text:SetJustifyH("CENTER")

		local bg = cell:CreateTexture()
		bg:SetAllPoints(cell)
		bg:SetColorTexture(0, 0, 0, 0.6)

		cellsCurrentlyShowing[cell] = true
		return cell
	end
end

do
	local function OnEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		local spellName = LoaderPublic.GetSpellName(self.spellID)
		if not IsSpellKnown(self.spellID) then
			GameTooltip:SetText(L.keystoneTeleportNotLearned:format(spellName))
		else
			local cd = LoaderPublic.GetSpellCooldown(self.spellID)
			if cd.startTime > 0 and cd.duration > 0 then
				local remainingSeconds = (cd.startTime + cd.duration) - GetTime()
				local hours = math.floor(remainingSeconds / 3600)
				remainingSeconds = remainingSeconds % 3600
				local minutes = math.floor(remainingSeconds / 60)
				GameTooltip:SetText(L.keystoneTeleportOnCooldown:format(spellName, hours, minutes))
			else
				GameTooltip:SetText(L.keystoneTeleportReady:format(spellName))
			end
		end
		GameTooltip:Show()
	end
	for mapID, spellID in next, teleports do
		local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
		teleportButtons[#teleportButtons+1] = button
		button.text = GetRealZoneText(mapID)
		button.spellID = spellID
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", spellID)
		button:Hide()
		button:SetSize(90, 48)
		button:SetScript("OnEnter", OnEnter)
		button:SetScript("OnLeave", GameTooltip_Hide)
		button:EnableMouse(true)
		button:RegisterForClicks("AnyDown", "AnyUp")

		local text = button:CreateFontString(nil, nil, "GameFontNormal")
		text:SetPoint("CENTER")
		text:SetSize(86, 44) -- Button size minus 4
		text:SetJustifyH("CENTER")
		text:SetText(button.text)
		while text:IsTruncated() do -- For really long single words like "MOTHERLODE!!"
			text:SetTextScale(text:GetTextScale() - 0.01)
		end

		local icon = button:CreateTexture()
		icon:SetSize(48, 48)
		icon:SetPoint("RIGHT", button, "LEFT", -4, 0)
		local texture = LoaderPublic.GetSpellTexture(spellID)
		icon:SetTexture(texture)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button.icon = icon

		local bg = button:CreateTexture(nil, nil, nil, -5)
		bg:SetAllPoints(button)
		bg:SetColorTexture(0, 0, 0, 0.6)

		button.cdbar = button:CreateTexture(nil, nil, nil, 5)
		button.cdbar:SetPoint("TOPLEFT")
		button.cdbar:SetPoint("BOTTOMLEFT")
		button.cdbar:SetColorTexture(1, 1, 1, 0.6)
		button.cdbar:Hide()
	end
	table.sort(teleportButtons, function(buttonA, buttonB)
		return buttonA.text < buttonB.text
	end)
	for i = 2, #teleportButtons do
		if i % 2 == 0 then
			teleportButtons[i]:SetPoint("LEFT", teleportButtons[i-1], "RIGHT", 60, 0)
		else
			teleportButtons[i]:SetPoint("TOP", teleportButtons[i-2], "BOTTOM", 0, -6)
		end
	end
end

do
	local function SelectTab(tab)
		tab.Left:Hide()
		tab.Middle:Hide()
		tab.Right:Hide()
		tab:Disable()
		tab:SetDisabledFontObject(GameFontHighlightSmall)

		tab.Text:SetPoint("CENTER", tab, "CENTER", 0, -3)

		tab.LeftActive:Show()
		tab.MiddleActive:Show()
		tab.RightActive:Show()

		PlaySound(841) -- SOUNDKIT.IG_CHARACTER_INFO_TAB
	end
	local function DeselectTab(tab)
		tab.Left:Show()
		tab.Middle:Show()
		tab.Right:Show()
		tab:Enable()

		tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 2)

		tab.LeftActive:Hide()
		tab.MiddleActive:Hide()
		tab.RightActive:Hide()
	end
	tab1:SetScript("OnClick", function(self)
		if prevTab == 2 then
			if InCombatLockdown() then
				LoaderPublic.Print(L.youAreInCombat)
				return
			else
				teleportButtons[1]:ClearAllPoints()
				teleportButtons[1]:SetScript("OnUpdate", nil)
				for i = 1, #teleportButtons do
					teleportButtons[i]:SetParent(nil)
					teleportButtons[i]:Hide()
				end
			end
		end
		prevTab = 1
		WipeCells()
		RequestData()

		partyHeader:SetText(L.keystoneHeaderParty)
		partyRefreshButton:Show()
		guildHeader:Show()
		guildRefreshButton:Show()

		SelectTab(tab1)
		DeselectTab(tab2)
		DeselectTab(tab3)
		DeselectTab(tab4)
	end)
	tab2:SetScript("OnClick", function(self)
		if InCombatLockdown() then
			LoaderPublic.Print(L.youAreInCombat)
			return
		end
		prevTab = 2
		WipeCells()

		partyHeader:SetText(L.keystoneTabTeleports)
		partyRefreshButton:Hide()
		guildHeader:Hide()
		guildRefreshButton:Hide()

		teleportButtons[1]:ClearAllPoints()
		teleportButtons[1]:SetPoint("TOPRIGHT", scrollChild, "TOP", 0, -40)
		local UnitCastingInfo = UnitCastingInfo
		teleportButtons[1]:SetScript("OnUpdate", function()
			local _, _, _, startTimeMs, endTimeMs, _, _, _, spellId = UnitCastingInfo("player")
			if spellId then
				for i = 1, #teleportButtons do
					if spellId == teleportButtons[i].spellID then
						local startTimeSec = startTimeMs / 1000
						local endTimeSec = endTimeMs / 1000
						local castDuration = endTimeSec - startTimeSec
						if castDuration > 0 then
							local percentage = (GetTime() - startTimeSec) / castDuration
							if percentage > 1 then percentage = 1 elseif percentage < 0 then percentage = 0 end
							teleportButtons[i].cdbar:SetColorTexture(0, 0, 1, 0.6)
							teleportButtons[i].cdbar:Show()
							teleportButtons[i].cdbar:SetWidth(percentage * teleportButtons[i]:GetWidth())
						else
							teleportButtons[i].cdbar:Hide()
						end
					end
				end
			else
				for i = 1, #teleportButtons do
					local cd = LoaderPublic.GetSpellCooldown(teleportButtons[i].spellID)
					if cd and cd.startTime > 0 and cd.duration > 2 and IsSpellKnown(teleportButtons[i].spellID) then
						local remaining = (cd.startTime + cd.duration) - GetTime()
						local percentage = remaining / cd.duration
						teleportButtons[i].cdbar:SetColorTexture(1, 0, 0, 0.6)
						teleportButtons[i].cdbar:Show()
						teleportButtons[i].cdbar:SetWidth(percentage * teleportButtons[i]:GetWidth())
					else
						teleportButtons[i].cdbar:Hide()
					end
				end
			end
		end)
		for i = 1, #teleportButtons do
			teleportButtons[i]:SetParent(scrollChild)
			teleportButtons[i]:Show()
			teleportButtons[i].cdbar:Hide()
			if not IsSpellKnown(teleportButtons[i].spellID) then
				teleportButtons[i].icon:SetTexture(136813)
			else
				local texture = LoaderPublic.GetSpellTexture(teleportButtons[i].spellID)
				teleportButtons[i].icon:SetTexture(texture)
			end
		end

		-- Calculate scroll height
		local contentsHeight = partyHeader:GetTop() - teleportButtons[#teleportButtons]:GetBottom()
		local newHeight = 10 + contentsHeight + 10 -- 10 top padding + content + 10 bottom padding
		scrollChild:SetHeight(newHeight)

		SelectTab(tab2)
		DeselectTab(tab1)
		DeselectTab(tab3)
		DeselectTab(tab4)
	end)
	tab3:SetScript("OnClick", function(self)
		if prevTab == 2 then
			if InCombatLockdown() then
				LoaderPublic.Print(L.youAreInCombat)
				return
			else
				teleportButtons[1]:ClearAllPoints()
				teleportButtons[1]:SetScript("OnUpdate", nil)
				for i = 1, #teleportButtons do
					teleportButtons[i]:SetParent(nil)
					teleportButtons[i]:Hide()
				end
			end
		end
		prevTab = 3
		WipeCells()

		partyHeader:SetText(L.keystoneHeaderMyCharacters)
		partyRefreshButton:Hide()
		guildHeader:Hide()
		guildRefreshButton:Hide()

		SelectTab(tab3)
		DeselectTab(tab1)
		DeselectTab(tab2)
		DeselectTab(tab4)

		-- Begin Display of alts
		UpdateMyKeystone()

		if BigWigs3DB.myKeystones then
			local sortedplayerList = {}
			for _, pData in next, BigWigs3DB.myKeystones do
				local decoratedName = nil
				local nameTooltip = pData.name .. " [" .. pData.realm .. "]"
				local specID = pData.specId
				if specID > 0 then
					local _, specName, _, specIcon, role, classFile, className = GetSpecializationInfoByID(specID)
					local color = C_ClassColor.GetClassColor(classFile):GenerateHexColor()
					decoratedName = format("|T%s:16:16:0:0:64:64:4:60:4:60|t%s|c%s%s|r", specIcon, roleIcons[role] or "", color, pData.name)
					nameTooltip = format("|c%s%s|r [%s] |A:classicon-%s:16:16|a%s |T%s:16:16:0:0:64:64:4:60:4:60|t%s %s%s", color, pData.name, pData.realm, classFile, className, specIcon, specName, roleIcons[role] or "", roleIcons[role] and _G[role] or "")
				end
				local challengeMapName, _, _, _, _, mapID = GetMapUIInfo(pData.keyMap)
				sortedplayerList[#sortedplayerList+1] = {
					name = pData.name, decoratedName = decoratedName, nameTooltip = nameTooltip,
					level = pData.keyLevel, levelTooltip = L.keystoneLevelTooltip:format(pData.keyLevel),
					map = dungeonNames[pData.keyMap] or pData.keyMap > 0 and pData.keyMap or "-", mapTooltip = L.keystoneMapTooltip:format(challengeMapName or "-"), mapID = mapID or tempTranslate[pData.keyMap],
					rating = pData.playerRating, ratingTooltip = L.keystoneRatingTooltip:format(pData.playerRating),
				}
			end
			-- Sort list by level descending, or by name if equal level
			table.sort(sortedplayerList, function(a, b)
				if a.level > b.level then
					return true
				elseif a.level == b.level then
					if a.rating ~= b.rating then -- If both levels are equal then sort by rating first, then sort by name
						return a.rating > b.rating
					else
						return a.name < b.name
					end
				end
			end)

			local prevName, prevLevel, prevMap, prevRating = nil, nil, nil, nil
			local tableSize = #sortedplayerList
			local _, _, _, _, _, _, _, instanceID = LoaderPublic.GetInstanceInfo()
			for i = 1, tableSize do
				local cellName, cellLevel, cellMap, cellRating = CreateCell(), CreateCell(), CreateCell(), CreateCell()
				if i == 1 then
					cellName:SetPoint("RIGHT", cellLevel, "LEFT", -6, 0)
					cellLevel:SetPoint("TOPLEFT", partyHeader, "CENTER", 3, -12)
					cellMap:SetPoint("LEFT", cellLevel, "RIGHT", 6, 0)
					cellRating:SetPoint("LEFT", cellMap, "RIGHT", 6, 0)
				else
					cellName:SetPoint("TOP", prevName, "BOTTOM", 0, -6)
					cellLevel:SetPoint("TOP", prevLevel, "BOTTOM", 0, -6)
					cellMap:SetPoint("TOP", prevMap, "BOTTOM", 0, -6)
					cellRating:SetPoint("TOP", prevRating, "BOTTOM", 0, -6)
				end
				cellName:SetWidth(WIDTH_NAME)
				cellName.text:SetText(sortedplayerList[i].decoratedName or sortedplayerList[i].name)
				cellName.tooltip = sortedplayerList[i].nameTooltip
				if instanceID == sortedplayerList[i].mapID then
					cellName.isGlowing = true
					LibStub("LibCustomGlow-1.0").PixelGlow_Start(cellName, nil, nil, 0.06) -- If you're in the dungeon of this players key, glow
				end
				cellLevel:SetWidth(WIDTH_LEVEL)
				cellLevel.text:SetText(sortedplayerList[i].level == -1 and hiddenIcon or sortedplayerList[i].level)
				cellLevel.tooltip = sortedplayerList[i].levelTooltip
				cellMap:SetWidth(WIDTH_MAP)
				cellMap.text:SetText(sortedplayerList[i].map)
				cellMap.tooltip = sortedplayerList[i].mapTooltip
				cellRating:SetWidth(WIDTH_RATING)
				cellRating.text:SetText(sortedplayerList[i].rating)
				cellRating.tooltip = sortedplayerList[i].ratingTooltip
				prevName, prevLevel, prevMap, prevRating = cellName, cellLevel, cellMap, cellRating

				if i == tableSize then
					-- Calculate scroll height
					local contentsHeight = partyHeader:GetTop() - prevName:GetBottom()
					local newHeight = 10 + contentsHeight + 10 -- 10 top padding + content + 10 bottom padding
					scrollChild:SetHeight(newHeight)
				end
			end
		end
	end)
	tab4:SetScript("OnClick", function(self)
		if prevTab == 2 then
			if InCombatLockdown() then
				LoaderPublic.Print(L.youAreInCombat)
				return
			else
				teleportButtons[1]:ClearAllPoints()
				teleportButtons[1]:SetScript("OnUpdate", nil)
				for i = 1, #teleportButtons do
					teleportButtons[i]:SetParent(nil)
					teleportButtons[i]:Hide()
				end
			end
		end
		prevTab = 4
		WipeCells()

		partyHeader:SetText(L.keystoneHeaderThisWeek)
		partyRefreshButton:Hide()
		guildHeader:SetText(L.keystoneHeaderOlder)
		guildHeader:Show()
		guildRefreshButton:Hide()

		SelectTab(tab4)
		DeselectTab(tab1)
		DeselectTab(tab2)
		DeselectTab(tab3)

		-- Begin Display of history
		local runs = C_MythicPlus.GetRunHistory(true, true)
		local tableSize = #runs
		local highestScoreByMap = {}
		for i = 1, tableSize do
			if not highestScoreByMap[runs[i].mapChallengeModeID] then
				highestScoreByMap[runs[i].mapChallengeModeID] = 0
			end
			if runs[i].runScore > highestScoreByMap[runs[i].mapChallengeModeID] then
				local diff = runs[i].runScore - highestScoreByMap[runs[i].mapChallengeModeID]
				highestScoreByMap[runs[i].mapChallengeModeID] = runs[i].runScore
				runs[i].gained = diff
			else
				runs[i].gained = 0
			end
		end
		local totalThisWeek = 0
		local firstOldRun = false
		local prevMapName, prevLevel, prevScore, prevGainedScore, prevInTime = nil, nil, nil, nil, nil
		for i = tableSize, 1, -1 do
			local cellMapName, cellLevel, cellScore, cellGainedScore, cellInTime = CreateCell(), CreateCell(), CreateCell(), CreateCell(), CreateCell()
			if runs[i].thisWeek then
				totalThisWeek = totalThisWeek + 1
				if i == tableSize then
					cellMapName:SetPoint("RIGHT", cellLevel, "LEFT", -6, 0)
					cellLevel:SetPoint("RIGHT", cellScore, "LEFT", -6, 0)
					cellScore:SetPoint("TOPLEFT", partyHeader, "CENTER", -6, -12)
					cellGainedScore:SetPoint("LEFT", cellScore, "RIGHT", 6, 0)
					cellInTime:SetPoint("LEFT", cellGainedScore, "RIGHT", 6, 0)
				else
					cellMapName:SetPoint("TOP", prevMapName, "BOTTOM", 0, -6)
					cellLevel:SetPoint("TOP", prevLevel, "BOTTOM", 0, -6)
					cellScore:SetPoint("TOP", prevScore, "BOTTOM", 0, -6)
					cellGainedScore:SetPoint("TOP", prevGainedScore, "BOTTOM", 0, -6)
					cellInTime:SetPoint("TOP", prevInTime, "BOTTOM", 0, -6)
				end
			else
				if not firstOldRun then
					firstOldRun = true
					cellMapName:SetPoint("RIGHT", cellLevel, "LEFT", -6, 0)
					cellLevel:SetPoint("RIGHT", cellScore, "LEFT", -6, 0)
					cellScore:SetPoint("TOPLEFT", guildHeader, "CENTER", -6, -12)
					cellGainedScore:SetPoint("LEFT", cellScore, "RIGHT", 6, 0)
					cellInTime:SetPoint("LEFT", cellGainedScore, "RIGHT", 6, 0)
				else
					cellMapName:SetPoint("TOP", prevMapName, "BOTTOM", 0, -6)
					cellLevel:SetPoint("TOP", prevLevel, "BOTTOM", 0, -6)
					cellScore:SetPoint("TOP", prevScore, "BOTTOM", 0, -6)
					cellGainedScore:SetPoint("TOP", prevGainedScore, "BOTTOM", 0, -6)
					cellInTime:SetPoint("TOP", prevInTime, "BOTTOM", 0, -6)
				end
			end

			cellMapName:SetWidth(WIDTH_MAP)
			cellMapName.text:SetText(dungeonNames[runs[i].mapChallengeModeID] or runs[i].mapChallengeModeID)
			cellMapName.tooltip = L.keystoneMapTooltip:format(GetMapUIInfo(runs[i].mapChallengeModeID) or "-")
			cellLevel:SetWidth(WIDTH_LEVEL)
			cellLevel.text:SetText(runs[i].level)
			cellLevel.tooltip = L.keystoneLevelTooltip:format(runs[i].level)
			cellScore:SetWidth(WIDTH_RATING)
			cellScore.text:SetText(runs[i].runScore)
			cellScore.tooltip = L.keystoneScoreTooltip:format(runs[i].runScore)
			cellGainedScore:SetWidth(WIDTH_RATING)
			cellGainedScore.text:SetText("+".. runs[i].gained)
			cellGainedScore.tooltip = L.keystoneScoreGainedTooltip:format(runs[i].gained)
			cellInTime:SetWidth(WIDTH_LEVEL)
			cellInTime.text:SetText(runs[i].completed and "|T136814:0|t" or "|T136813:0|t")
			cellInTime.tooltip = runs[i].completed and L.keystoneCompletedTooltip or L.keystoneFailedTooltip
			prevMapName, prevLevel, prevScore, prevGainedScore, prevInTime = cellMapName, cellLevel, cellScore, cellGainedScore, cellInTime

			if i == 1 then
				-- Calculate scroll height
				local contentsHeight = partyHeader:GetTop() - prevMapName:GetBottom()
				local newHeight = 10 + contentsHeight + 10 -- 10 top padding + content + 10 bottom padding
				scrollChild:SetHeight(newHeight)
			end
		end

		guildHeader:ClearAllPoints()
		local y = 24 + totalThisWeek*26
		guildHeader:SetPoint("TOP", partyHeader, "BOTTOM", 0, -y)
	end)
end

function RequestData()
	partyList = {}
	guildList = {}
	LibSpec.RequestGuildSpecialization()
	mainPanel:Show()
	LibKeystone.Request("PARTY")
	C_Timer.After(0.2, function() LibKeystone.Request("GUILD") end)
	tab1:Click()
end

local function UpdateCells(playerList, isGuildList)
	local sortedplayerList = {}
	for pName, pData in next, playerList do
		if not isGuildList or (isGuildList and not partyList[pName]) then
			local decoratedName = nil
			local nameTooltip = pName
			local specID = specs[pName]
			if specID then
				local _, specName, _, specIcon, role, classFile, className = GetSpecializationInfoByID(specID)
				local color = C_ClassColor.GetClassColor(classFile):GenerateHexColor()
				decoratedName = format("|T%s:16:16:0:0:64:64:4:60:4:60|t%s|c%s%s|r", specIcon, roleIcons[role] or "", color, gsub(pName, "%-.+", "*"))
				nameTooltip = format("|c%s%s|r |A:classicon-%s:16:16|a%s |T%s:16:16:0:0:64:64:4:60:4:60|t%s %s%s", color, pName, classFile, className, specIcon, specName, roleIcons[role] or "", roleIcons[role] and _G[role] or "")
			end
			local challengeMapName, _, _, _, _, mapID = GetMapUIInfo(pData[2])
			sortedplayerList[#sortedplayerList+1] = {
				name = pName, decoratedName = decoratedName, nameTooltip = nameTooltip,
				level = pData[1], levelTooltip = L.keystoneLevelTooltip:format(pData[1] == -1 and L.keystoneHiddenTooltip or pData[1]),
				map = pData[2] == -1 and hiddenIcon or dungeonNames[pData[2]] or "-", mapTooltip = L.keystoneMapTooltip:format(pData[2] == -1 and L.keystoneHiddenTooltip or challengeMapName or "-"), mapID = mapID or tempTranslate[pData[2]],
				rating = pData[3], ratingTooltip = L.keystoneRatingTooltip:format(pData[3]),
			}
		end
	end
	-- Sort list by level descending, or by name if equal level
	table.sort(sortedplayerList, function(a, b)
		local firstLevel = a.level == -1 and 1 or a.level
		local secondLevel = b.level == -1 and 1 or b.level
		if firstLevel > secondLevel then
			return true
		elseif firstLevel == secondLevel then
			if a.rating ~= b.rating then -- If both levels are equal then sort by rating first, then sort by name
				return a.rating > b.rating
			else
				return a.name < b.name
			end
		end
	end)

	local prevName, prevLevel, prevMap, prevRating = nil, nil, nil, nil
	local tableSize = #sortedplayerList
	local _, _, _, _, _, _, _, instanceID = LoaderPublic.GetInstanceInfo()
	for i = 1, tableSize do
		local cellName, cellLevel, cellMap, cellRating = CreateCell(), CreateCell(), CreateCell(), CreateCell()
		if i == 1 then
			cellName:SetPoint("RIGHT", cellLevel, "LEFT", -6, 0)
			cellLevel:SetPoint("TOPLEFT", isGuildList and guildHeader or partyHeader, "CENTER", 3, -12)
			cellMap:SetPoint("LEFT", cellLevel, "RIGHT", 6, 0)
			cellRating:SetPoint("LEFT", cellMap, "RIGHT", 6, 0)
		else
			cellName:SetPoint("TOP", prevName, "BOTTOM", 0, -6)
			cellLevel:SetPoint("TOP", prevLevel, "BOTTOM", 0, -6)
			cellMap:SetPoint("TOP", prevMap, "BOTTOM", 0, -6)
			cellRating:SetPoint("TOP", prevRating, "BOTTOM", 0, -6)
		end
		cellName:SetWidth(WIDTH_NAME)
		cellName.text:SetText(sortedplayerList[i].decoratedName or sortedplayerList[i].name)
		cellName.tooltip = sortedplayerList[i].nameTooltip
		if not isGuildList and instanceID == sortedplayerList[i].mapID then
			cellName.isGlowing = true
			LibStub("LibCustomGlow-1.0").PixelGlow_Start(cellName, nil, nil, 0.06) -- If you're in the dungeon of this players key, glow
		end
		cellLevel:SetWidth(WIDTH_LEVEL)
		cellLevel.text:SetText(sortedplayerList[i].level == -1 and hiddenIcon or sortedplayerList[i].level)
		cellLevel.tooltip = sortedplayerList[i].levelTooltip
		cellMap:SetWidth(WIDTH_MAP)
		cellMap.text:SetText(sortedplayerList[i].map)
		cellMap.tooltip = sortedplayerList[i].mapTooltip
		cellRating:SetWidth(WIDTH_RATING)
		cellRating.text:SetText(sortedplayerList[i].rating)
		cellRating.tooltip = sortedplayerList[i].ratingTooltip
		prevName, prevLevel, prevMap, prevRating = cellName, cellLevel, cellMap, cellRating

		if i == tableSize then
			-- Calculate scroll height
			local contentsHeight = partyHeader:GetTop() - prevName:GetBottom()
			local newHeight = 10 + contentsHeight + 10 -- 10 top padding + content + 10 bottom padding
			scrollChild:SetHeight(newHeight)
		end
	end

	if not isGuildList then
		guildHeader:ClearAllPoints()
		local y = 24 + tableSize*26
		guildHeader:SetPoint("TOP", partyHeader, "BOTTOM", 0, -y)
	end
end

LibKeystone.Register({}, function(keyLevel, keyMap, playerRating, playerName, channel)
	if channel == "PARTY" then
		partyList[playerName] = {keyLevel, keyMap, playerRating}

		if mainPanel:IsShown() and not tab1:IsEnabled() then
			WipeCells()
			UpdateCells(partyList)
			UpdateCells(guildList, true)
		end
	elseif channel == "GUILD" then
		guildList[playerName] = {keyLevel, keyMap, playerRating}

		if mainPanel:IsShown() and not tab1:IsEnabled() then
			WipeCells()
			UpdateCells(partyList)
			UpdateCells(guildList, true)
		end
	end
end)

do
	local function voiceSorting()
		local list = BigWigsAPI.GetCountdownList()
		local sorted = {}
		for k in next, list do
			if k ~= L.none then
				sorted[#sorted + 1] = k
			end
		end
		table.sort(sorted, function(a, b) return list[a] < list[b] end)
		table.insert(sorted, 1, L.none)
		return sorted
	end

	local function ShowViewer()
		if not mainPanel:IsShown() then
			RequestData()
		end
	end

	local _, addonTbl = ...
	addonTbl.API.RegisterSlashCommand("/key", ShowViewer)
	addonTbl.API.RegisterSlashCommand("/bwkey", ShowViewer)

	addonTbl.API.SetToolOptionsTable("MythicPlus", {
		type = "group",
		childGroups = "tab",
		name = L.keystoneModuleName,
		get = function(info)
			return db.profile[info[#info]]
		end,
		set = function(info, value)
			local key = info[#info]
			db.profile[key] = value
		end,
		args = {
			explainer = {
				type = "description",
				name = L.keystoneExplainer,
				order = 0,
				width = "full",
				fontSize = "large",
			},
			general = {
				type = "group",
				name = L.general,
				order = 1,
				args = {
					autoSlotKeystone = {
						type = "toggle",
						name = L.keystoneAutoSlot,
						desc = L.keystoneAutoSlotDesc,
						order = 1,
						width = "full",
					},
					spacer = {
						type = "description",
						name = "\n\n",
						order = 2,
						width = "full",
					},
					countdown = {
						type = "group",
						name = L.countdown,
						order = 3,
						inline = true,
						width = "full",
						args = {
							countdownExplainer = {
								type = "description",
								name = L.keystoneCountdownExplainer,
								order = 1,
								width = "full",
							},
							countBegin = {
								name = L.countdownBegins,
								desc = L.keystoneCountdownBeginsDesc,
								type = "range", min = 3, max = 9, step = 1,
								order = 2,
								width = 1
							},
							countVoice = {
								name = L.countdownVoice,
								type = "select",
								values = BigWigsAPI.GetCountdownList,
								sorting = voiceSorting,
								order = 3,
								width = 2,
							},
						},
					},
					suggestions = { -- XXX temp
						type = "description",
						name = "\n\n\n|cFF33FF99Want more features? Have some ideas?\nSubmit your suggestions on our Discord!|r",
						order = 4,
						width = "full",
						fontSize = "medium",
					},
				},
			},
			keystoneViewer = {
				type = "group",
				name = L.keystoneViewerTitle,
				order = 2,
				args = {
					explainViewer = {
						type = "description",
						name = L.keystoneViewerExplainer,
						order = 1,
						width = "full",
					},
					openViewer = {
						type = "execute",
						name = L.keystoneViewerOpen,
						func = ShowViewer,
						order = 2,
						width = 1.5,
					},
					spacerViewer = {
						type = "description",
						name = "\n\n",
						order = 3,
						width = "full",
					},
					autoShowZoneIn = {
						type = "toggle",
						name = L.keystoneAutoShowZoneIn,
						desc = L.keystoneAutoShowZoneInDesc,
						order = 4,
						width = "full",
					},
					autoShowEndOfRun = {
						type = "toggle",
						name = L.keystoneAutoShowEndOfRun,
						desc = L.keystoneAutoShowEndOfRunDesc,
						order = 5,
						width = "full",
					},
					hideFromGuild = {
						type = "toggle",
						name = L.keystoneHideGuildTitle,
						desc = L.keystoneHideGuildDesc,
						order = 6,
						width = "full",
						set = function(info, value)
							local key = info[#info]
							db.profile[key] = value
							LibKeystone.SetGuildHidden(value)
						end,
						confirm = function(_, value)
							if value then
								return L.keystoneHideGuildWarning
							end
						end,
					},
				},
			},
		},
	})
end
