-------------------------------------------------------------------------------
-- Module Declaration
--

local plugin, L = BigWigs:NewPlugin("Wipe")
if not plugin then return end

-------------------------------------------------------------------------------
-- Locals
--

local media = LibStub("LibSharedMedia-3.0")
local SOUND = media.MediaType and media.MediaType.SOUND or "sound"

-------------------------------------------------------------------------------
-- Options
--

plugin.defaultDB = {
	wipeSound = "None",
	respawnBar = true,
}

plugin.pluginOptions = {
	name = "|TInterface\\AddOns\\BigWigs\\Media\\Icons\\Menus\\Wipe:20|t ".. L.wipe,
	type = "group",
	childGroups = "tab",
	order = 8,
	get = function(i) return plugin.db.profile[i[#i]] end,
	set = function(i, value)
		local n = i[#i]
		plugin.db.profile[n] = value
	end,
	args = {
		wipeSound = {
			type = "select",
			name = L.wipeSoundTitle,
			order = 1,
			get = function(info)
				for i, v in next, media:List(SOUND) do
					if v == plugin.db.profile[info[#info]] then
						return i
					end
				end
			end,
			set = function(info, value)
				plugin.db.profile[info[#info]] = media:List(SOUND)[value]
			end,
			values = media:List(SOUND),
			width = 2,
			itemControl = "DDI-Sound",
		},
		spacer = {
			type = "description",
			name = "\n",
			order = 1.1,
			width = "full",
		},
		respawnBar = {
			type = "toggle",
			name = L.showRespawnBar,
			desc = L.showRespawnBarDesc,
			order = 2,
			width = "full",
		},
	},
}

-------------------------------------------------------------------------------
-- Initialization
--

do
	local function updateProfile()
		local db = plugin.db.profile

		for k, v in next, db do
			local defaultType = type(plugin.defaultDB[k])
			if defaultType == "nil" then
				db[k] = nil
			elseif type(v) ~= defaultType then
				db[k] = plugin.defaultDB[k]
			end
		end
	end

	function plugin:OnPluginEnable()
		self:RegisterMessage("BigWigs_EncounterEnd")

		self:RegisterMessage("BigWigs_ProfileUpdate", updateProfile)
		updateProfile()
	end
end

-------------------------------------------------------------------------------
-- Event Handlers
--

function plugin:BigWigs_EncounterEnd(_, module, _, _, _, _, status)
	if status == 0 and module then
		if module:GetRespawnTime() and self.db.profile.respawnBar then
			local time = module:GetRespawnTime()
			self:SendMessage("BigWigs_StartBar", self, nil, L.respawn, time, 236372) -- 236372 = "Interface\\Icons\\achievement_bg_returnxflags_def_wsg"
			self:SendMessage("BigWigs_Timer", self, nil, time, time, L.respawn, 0, 236372, false, true)
		end
		if module:GetJournalID() or module:GetAllowWin() then
			local soundName = self.db.profile.wipeSound
			if soundName ~= "None" then
				local sound = media:Fetch(SOUND, soundName, true)
				if sound then
					self:PlaySoundFile(sound)
				end
			end
		end
	end
end
