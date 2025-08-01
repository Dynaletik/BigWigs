if not BigWigsLoader.isNext then return end

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Loom'ithar", 2810, 2686)
if not mod then return end
mod:RegisterEnableMob(233815) -- Loom'ithar
mod:SetEncounterID(3131)
mod:SetRespawnTime(30)
mod:SetStage(1)

--------------------------------------------------------------------------------
-- Locals
--

local lairWeavingCount = 1
local overinfusionBurstCount = 1
local infusionTetherCount = 1
local piercingStrandCount = 1

local arcaneOutrageCount = 1
local writhingWaveCount = 1

local infusionPylonCount = 1

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.lair_weaving = "Webs" -- Webs that spawn on the edge of the room
	L.infusion_pylons = "Pylons" -- Short for Infusion Pylons
end

--------------------------------------------------------------------------------
-- Initialization
--

function mod:OnRegister()
	self:SetSpellRename(1237272, L.lair_weaving) -- Lair Weaving (Webs)
	self:SetSpellRename(1238502, CL.shield) -- Woven Ward (Shield)
	self:SetSpellRename(1226395, CL.full_energy) -- Overinfusion Burst (Full Energy)
	self:SetSpellRename(1226311, CL.pull_in) -- Infusion Tether (Pull In)
	self:SetSpellRename(1226721, CL.stunned) -- Silken Snare (Stunned)
	self:SetSpellRename(1237212, CL.tank_frontal) -- Piercing Strand (Tank Frontal)
	self:SetSpellRename(1228059, CL.knockback) -- Unbound Rage (Knockback)
	self:SetSpellRename(1246921, L.infusion_pylons) -- Infusion Pylons (Pylons)
	self:SetSpellRename(1227782, CL.pushback) -- Arcane Outrage (Pushback)
	self:SetSpellRename(1227226, CL.soak) -- Writhing Wave (Soak)
end

function mod:GetOptions()
	return {
		"stages",
		-- Stage One: The Arcane Loom
			1237272, -- Lair Weaving
				1238502, -- Woven Ward
			{1226311, "ME_ONLY_EMPHASIZE"}, -- Infusion Tether
				1226366, -- Living Silk
				1226721, -- Silken Snare
			1226395, -- Overinfusion Burst
			-- 1226867, -- Primal Spellstorm XXX No cast events, just passive dodges?
			{1237212, "TANK"}, -- Piercing Strand
		-- Stage Two: The Beast Unbound
			{1228059, "COUNTDOWN"}, -- Unbound Rage
				1243771, -- Arcane Ichor
			1227782, -- Arcane Outrage
			1227226, -- Writhing Wave
		-- Mythic
			1246921, -- Infusion Pylons
	},{
		{
			tabName = CL.general,
			{"stages"},
		},
		{
			tabName = CL.stage:format(1),
			{1237272, 1238502, 1226311, 1226366, 1226721, 1226395, 1237212, 1246921},
		},
		{
			tabName = CL.stage:format(2),
			{1228059, 1243771, 1227782, 1227226}
		},
		[1246921] = "mythic", -- Infusion Pylons
	},{
		[1237272] = L.lair_weaving, -- Lair Weaving (Webs)
		[1238502] = CL.removed:format(CL.shield), -- Woven Ward (Shield Removed)
		[1226395] = CL.full_energy, -- Overinfusion Burst (Full Energy)
		[1226311] = CL.pull_in, -- Infusion Tether (Pull In)
		[1226721] = CL.stunned, -- Silken Snare (Stunned)
		[1237212] = CL.tank_frontal, -- Piercing Strand (Tank Frontal)
		[1228059] = CL.knockback, -- Unbound Rage (Knockback)
		[1246921] = L.infusion_pylons, -- Infusion Pylons (Pylons)
		[1227782] = CL.pushback, -- Arcane Outrage (Pushback)
		[1227226] = CL.soak, -- Writhing Wave (Soak)

	}
end

function mod:OnBossEnable()
	self:RegisterEvent("CHAT_MSG_RAID_BOSS_WHISPER") -- Infusion Pylons
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")

	-- Stage One: The Arcane Loom
	self:Log("SPELL_CAST_SUCCESS", "LairWeaving", 1237272)
	self:Log("SPELL_MISSED", "ShieldRemoved", 1227742) -- Piercing Strand missing an web removes the shield.
	self:Log("SPELL_CAST_SUCCESS", "OverinfusionBurst", 1226395)
	-- self:Log("SPELL_CAST_SUCCESS", "InfusionTether", 1226315)
	self:Log("SPELL_AURA_APPLIED", "InfusionTetherApplied", 1226311)
	self:Log("SPELL_AURA_APPLIED", "LivingSilkDamage", 1226366)
	self:Log("SPELL_PERIODIC_DAMAGE", "LivingSilkDamage", 1226366)
	self:Log("SPELL_PERIODIC_MISSED", "LivingSilkDamage", 1226366)
	self:Log("SPELL_AURA_APPLIED", "SilkenSnareApplied", 1226721)
	self:Log("SPELL_CAST_START", "PiercingStrand", 1227263)
	self:Log("SPELL_AURA_APPLIED", "PiercingStrandApplied", 1237212)
	-- Intermission: Unravelling
	self:Log("SPELL_AURA_APPLIED", "ArcaneIchorDamage", 1243771)
	self:Log("SPELL_PERIODIC_DAMAGE", "ArcaneIchorDamage", 1243771)
	self:Log("SPELL_PERIODIC_MISSED", "ArcaneIchorDamage", 1243771)
	-- Stage Two: The Beast Unbound
	self:Log("SPELL_CAST_START", "ArcaneOutrage", 1227782)
	self:Log("SPELL_CAST_START", "WrithingWave", 1227226)
end

function mod:OnEngage()
	self:SetStage(1)

	lairWeavingCount = 1
	overinfusionBurstCount = 1
	infusionTetherCount = 1
	piercingStrandCount = 1
	infusionPylonCount = 1

	self:Bar(1237212, self:Mythic() and 12.7 or 9.5, CL.count:format(CL.tank_frontal, piercingStrandCount)) -- Piercing Strand
	self:Bar(1226311, 22.0, CL.count:format(CL.pull_in, infusionTetherCount)) -- Infusion Tether
	self:Bar(1237272, self:Easy() and 44.0 or 0.5, CL.count:format(L.lair_weaving, lairWeavingCount)) -- Lair Weaving
	self:Bar(1226395, 76.0, CL.count:format(CL.full_energy, overinfusionBurstCount)) -- Overinfusion Burst

	if self:Mythic() then
		self:Bar(1246921, 10.0, CL.count:format(L.infusion_pylons, infusionPylonCount))
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:CHAT_MSG_RAID_BOSS_WHISPER(_, msg)
	-- |TInterface\\ICONS\\Spell_Mage_Overpowered.blp|t |cFFFF0000|Hspell:1246921|h[Infusion Pylons]|h|r begin to turn on!#Loom'ithar#0#false",
	if msg:find("spell:1246921", nil, true) then
		self:Message(1246921, "yellow", CL.count:format(L.infusion_pylons, infusionPylonCount))
		self:PlaySound(1246921, "long")
		infusionPylonCount = infusionPylonCount + 1
		self:Bar(1246921, infusionPylonCount % 2 == 0 and 30.0 or 55, CL.count:format(L.infusion_pylons, infusionPylonCount))
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, _, _, spellId)
	if spellId == 1227775 then -- Energy Controller 2 [DNT], Stage 2 start
		-- Correct timers incase
		self:Bar(1227226, {3.0, 16.0}, CL.count:format(CL.soak, writhingWaveCount)) -- Writhing Wave
		self:Bar(1227782, {10.0, 23.0}, CL.count:format(CL.pushback, arcaneOutrageCount)) -- Arcane Outrage
	elseif spellId == 1228059 then -- Unbound Rage, Stage 2 Starting
		self:Message("stages", "green", CL.stage:format(2), false)
		self:PlaySound("stages", "long")
		self:SetStage(2)

		self:StopBar(CL.count:format(L.lair_weaving, lairWeavingCount)) -- Lair Weaving
		self:StopBar(CL.count:format(CL.full_energy, overinfusionBurstCount)) -- Overinfusion Burst
		self:StopBar(CL.count:format(CL.pull_in, infusionTetherCount)) -- Infusion Tether
		self:StopBar(CL.count:format(CL.tank_frontal, piercingStrandCount)) -- Piercing Strand
		self:StopBar(CL.count:format(L.infusion_pylons, infusionPylonCount))

		arcaneOutrageCount = 1
		writhingWaveCount = 1

		self:Bar(1228059, 5.8, CL.knockback)
		self:Bar(1227226, 16.0, CL.count:format(CL.soak, writhingWaveCount)) -- Writhing Wave
		self:Bar(1227782, 23.0, CL.count:format(CL.pushback, arcaneOutrageCount)) -- Arcane Outrage
	end
end

function mod:LairWeaving(args)
	self:StopBar(CL.count:format(L.lair_weaving, lairWeavingCount))
	self:Message(args.spellId, "orange", CL.count:format(L.lair_weaving, lairWeavingCount))
	self:PlaySound(args.spellId, "alert") -- ring coming, kill for gap?
	lairWeavingCount = lairWeavingCount + 1
	local cd = 85
	if self:Heroic() then
		cd = lairWeavingCount % 2 == 1 and 41.5 or 43.5
	elseif self:Mythic() then
		cd = lairWeavingCount % 2 == 1 and (lairWeavingCount % 4 == 3 and 36.5 or 34.5) or 7.0
	end
	self:Bar(args.spellId, cd, CL.count:format(L.lair_weaving, lairWeavingCount))
end

function mod:ShieldRemoved(args)
	if self:MobId(args.destGUID) == 245173 then -- Infused Tangle
		self:Message(1238502, "green", CL.removed:format(CL.shield)) -- Woven Ward
		self:PlaySound(1238502, "info") -- shield removed
	end
end

function mod:OverinfusionBurst(args)
	self:StopBar(CL.count:format(CL.full_energy, overinfusionBurstCount))
	self:Message(args.spellId, "red", CL.count:format(CL.full_energy, overinfusionBurstCount))
	self:PlaySound(args.spellId, "warning") -- move away
	overinfusionBurstCount = overinfusionBurstCount + 1
	local cd = 85
	self:Bar(args.spellId, cd, CL.count:format(CL.full_energy, overinfusionBurstCount))
end

do
	local prev = 0
	function mod:InfusionTetherApplied(args)
		if args.time - prev > 2 then
			prev = args.time
			self:StopBar(CL.count:format(CL.pull_in, overinfusionBurstCount))
			self:Message(1226311, "cyan", CL.count:format(CL.pull_in, overinfusionBurstCount))
			overinfusionBurstCount = overinfusionBurstCount + 1
			local cd = overinfusionBurstCount % 2 == 1 and 46 or 39
			if not self:Easy() then
				cd = overinfusionBurstCount % 2 == 1 and 41 or 44
			end
			self:Bar(1226311, cd, CL.count:format(CL.pull_in, overinfusionBurstCount))
		end
		if self:Me(args.destGUID) then
			self:PersonalMessage(args.spellId, nil, CL.pull_in)
			self:PlaySound(args.spellId, "warning") -- break tether
		end
	end
end

do
	local prev = 0
	function mod:LivingSilkDamage(args)
		if self:Me(args.destGUID) and args.time - prev > 2 then
			prev = args.time
			self:PlaySound(args.spellId, "underyou")
			self:PersonalMessage(args.spellId, "underyou")
		end
	end
end

function mod:SilkenSnareApplied(args)
	if self:Me(args.destGUID) then
		self:PersonalMessage(args.spellId, nil, CL.stunned)
		self:PlaySound(args.spellId, "warning") -- stunned
	end
end

function mod:PiercingStrand()
	self:StopBar(CL.count:format(CL.tank_frontal, piercingStrandCount))
	self:Message(1237212, "purple", CL.count:format(CL.tank_frontal, piercingStrandCount))
	self:PlaySound(1237212, "alert") -- tank hit inc
	piercingStrandCount = piercingStrandCount + 1
	-- every 2nd is fast, others alternate in speed
	local cd = piercingStrandCount % 2 == 0 and (self:Mythic() and 4 or 5.5) or piercingStrandCount % 4 == 3 and 39.5 or (self:Mythic() and 36.5 or 33.5)
	self:Bar(1237212, cd, CL.count:format(CL.tank_frontal, piercingStrandCount))
end

function mod:PiercingStrandApplied(args)
	self:TargetMessage(args.spellId, "purple", args.destName)
	if self:Me(args.destGUID) then
		self:PlaySound(args.spellId, "alarm") -- big dot
	elseif self:Tank() then
		self:PlaySound(args.spellId, "warning") -- taunt?
	end
end


-- Stage Two: The Beast Unbound
do
	local prev = 0
	function mod:ArcaneIchorDamage(args)
		if self:Me(args.destGUID) and args.time - prev > 2 then
			prev = args.time
			self:PlaySound(args.spellId, "underyou")
			self:PersonalMessage(args.spellId, "underyou")
		end
	end
end

function mod:ArcaneOutrage(args)
	self:StopBar(CL.count:format(CL.pushback, arcaneOutrageCount))
	self:Message(args.spellId, "yellow", CL.count:format(CL.pushback, arcaneOutrageCount))
	self:PlaySound(args.spellId, "alert") -- watch pools spawning?
	arcaneOutrageCount = arcaneOutrageCount + 1
	self:Bar(args.spellId, 20, CL.count:format(CL.pushback, arcaneOutrageCount))
end

function mod:WrithingWave(args)
	self:StopBar(CL.count:format(CL.soak, writhingWaveCount))
	self:Message(args.spellId, "purple", CL.count:format(CL.soak, writhingWaveCount))
	self:PlaySound(args.spellId, "warning") -- soak or avoid
	writhingWaveCount = writhingWaveCount + 1
	self:Bar(args.spellId, 20, CL.count:format(CL.soak, writhingWaveCount))
end
