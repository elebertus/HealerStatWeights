local name,addon = ...;
local hsw = LibStub("AceAddon-3.0"):NewAddon("HealerStatWeights", "AceConsole-3.0", "AceEvent-3.0")



--[[----------------------------------------------------------------------------
Defaults
------------------------------------------------------------------------------]]
local defaults = {
	global = {
		excludeRaidHealingCooldowns=false,
		useHPMoverHPCT=true,
		useVersDR=false,
		useCritResurg=false,
		fontSize=12,
		frameWidth=192,
		enabledInNormalDungeons=false,
		enabledInHeroicDungeons=false,
		enabledInMythicDungeons=false,
		enabledInMythicPlusDungeons=true,
		enabledInLfrRaids=false,
		enabledInNormalRaids=false,
		enabledInHeroicRaids=false,
		enabledInMythicRaids=true,
		frameLocked=false,
		maxSegments=10 
	}
}



--[[----------------------------------------------------------------------------
Options
------------------------------------------------------------------------------]]
local options = {
	name = "Healer Stat Weights",
	handler = hsw,
	childGroups = "tab",
	type = "group",
	args = {
		headerSettings = {
			name = "Calculation Settings",
			desc = "These settings control which calculations are performed. Can be toggled retroactively for past segments.",
			type = "header",
			order = 1
		},
		useHPM = {
			name = "Exclude Haste Effects on Cast Time (Use HPM over HPCT)",
			desc = "When checked, excludes the effects of haste on increased cast time. Can be toggled retroactively for past segments.",
			type = "toggle",
			order = 3,
			width = "full",
			get = function(info) return hsw.db.global.useHPMoverHPCT end,
			set = function(info,val) hsw.db.global.useHPMoverHPCT = val; addon:UpdateDisplayLabels(); addon:UpdateDisplayStats(); end
		},
		useVersDR = {
			name = "Include Damage Reduction effects on Versatility",
			desc = "When checked, includes the damage reduction effects of versatility. Can be toggled retroactively for past segments.",
			type = "toggle",
			order = 4,
			width = "full",
			get = function(info) return hsw.db.global.useVersDR end,
			set = function(info,val) hsw.db.global.useVersDR = val; addon:UpdateDisplayLabels(); addon:UpdateDisplayStats(); end
		},
		useCritResurg = {
			name = "Include Resurgence effects on Critical Strike (Shaman Only)",
			desc = "When checked, includes the value from mana gained through resurgence in the critical strike rating. Can be toggled retroactively for past segments.",
			type = "toggle",
			order = 5,
			width = "full",
			get = function(info) return hsw.db.global.useCritResurg end,
			set = function(info,val) hsw.db.global.useCritResurg = val; addon:UpdateDisplayLabels(); addon:UpdateDisplayStats(); end
		},
		excludeBigCDs = {
			name = "Exclude Raid Healing Cooldowns",
			desc = "When checked, excludes effects from big healing cooldowns, such as tranquility. Is NOT retroactive for past segments. Set this value before starting combat.",
			type = "toggle",
			order = 6,
			width = "full",
			get = function(info) return hsw.db.global.excludeRaidHealingCooldowns end,
			set = function(info,val) hsw.db.global.excludeRaidHealingCooldowns = val end
		},
		headerUI = {
			name = "UI Settings",
			desc = "These settings affect the UI of the addon.",
			type = "header",
			order = 7
		},
		showFrame = {
			name = "Show Frame",
			type = "toggle",
			desc = "Show or hide the stat weights frame.",
			order = 8,
			width = "full",
			get = function(info) return addon.frameVisible end,
			set = function(info,val)
				if ( val ) then
					addon:Show();
				else
					addon:Hide();
				end
			end
		},
		frameLocked = {
			name = "Lock Frame",
			desc = "Disable moving the stat weights frame by clicking & dragging.",
			type = "toggle",
			order = 9,
			width = "full",
			get = function(info) return hsw.db.global.frameLocked end,
			set = function(info,val) 
				hsw.db.global.frameLocked = val;
				if ( val ) then 
					addon:Lock(); 
				else 
					addon:Unlock(); 
				end
			end
		},
		fontSize = {
			name = "Font Size",
			desc = "Adjust the font size of the stat weights frame.",
			type = "range",
			order=10,
			min=8,
			max=18,
			step=1,
			get = function(info) return hsw.db.global.fontSize end,
			set = function(info,val) 
				hsw.db.global.fontSize = val;
				addon:AdjustFontSizes();
			end
		},
		frameWidth = {
			name = "Frame Width",
			desc = "Adjust the width of the stat weights frame.",
			type = "range",
			order=11,
			min=128,
			max=256,
			step=1,
			get = function(info) return hsw.db.global.frameWidth end,
			set = function(info,val) 
				hsw.db.global.frameWidth = val;
				addon:AdjustWidth(val);
			end
		},
		headerContentAndDifficulty = {
			name = "Content and Difficulty",
			desc = "These settings control which content and difficulties to calculate statweights for.",
			type = "header",
			order = 12
		},
		enabledInNormalDungeons = {
			name = "Dungeons (Normal)",
			type = "toggle",
			order = 13,
			width = "full",
			get = function(info) return hsw.db.global.enabledInNormalDungeons end,
			set = function(info,val) hsw.db.global.enabledInNormalDungeons = val; addon:AdjustVisibility(); end
		},
		enabledInHeroicDungeons = {
			name = "Dungeons (Heroic)",
			type = "toggle",
			order = 14,
			width = "full",
			get = function(info) return hsw.db.global.enabledInHeroicDungeons end,
			set = function(info,val) hsw.db.global.enabledInHeroicDungeons = val; addon:AdjustVisibility(); end
		},
		enabledInMythicDungeons = {
			name = "Dungeons (Mythic)",
			type = "toggle",
			order = 15,
			width = "full",
			get = function(info) return hsw.db.global.enabledInMythicDungeons end,
			set = function(info,val) hsw.db.global.enabledInMythicDungeons = val; addon:AdjustVisibility(); end
		},
		enabledInMythicPlusDungeons = {
			name = "Dungeons (Mythic+)",
			type = "toggle",
			order = 16,
			width = "full",
			get = function(info) return hsw.db.global.enabledInMythicPlusDungeons end,
			set = function(info,val) hsw.db.global.enabledInMythicPlusDungeons = val; addon:AdjustVisibility(); end
		},
		enabledInLfrRaids = {
			name = "Raids (LFR)",
			type = "toggle",
			order = 17,
			width = "full",
			get = function(info) return hsw.db.global.enabledInLfrRaids end,
			set = function(info,val) hsw.db.global.enabledInLfrRaids = val; addon:AdjustVisibility(); end
		},
		enabledInNormalRaids = {
			name = "Raids (Normal)",
			type = "toggle",
			order = 18,
			width = "full",
			get = function(info) return hsw.db.global.enabledInNormalRaids end,
			set = function(info,val) hsw.db.global.enabledInNormalRaids = val; addon:AdjustVisibility(); end
		},
		enabledInHeroicRaids = {
			name = "Raids (Heroic)",
			type = "toggle",
			order = 19,
			width = "full",
			get = function(info) return hsw.db.global.enabledInHeroicRaids end,
			set = function(info,val) hsw.db.global.enabledInHeroicRaids = val; addon:AdjustVisibility(); end
		},
		enabledInMythicRaids = {
			name = "Raids (Mythic)",
			type = "toggle",
			order = 20,
			width = "full",
			get = function(info) return hsw.db.global.enabledInMythicRaids end,
			set = function(info,val) hsw.db.global.enabledInMythicRaids = val; addon:AdjustVisibility(); end
		}
	}
}



--[[----------------------------------------------------------------------------
Handle Chat Commands
------------------------------------------------------------------------------]]
function hsw:ChatCommand(input)
    if not input or input:trim() == "" then
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
	end
	
	local lwr_input = string.lower(input);
	
	if ( lwr_input == "show" ) then
		addon:Show();
	elseif ( lwr_input == "hide" ) then
		addon:Hide();
	elseif ( lwr_input == "lock" ) then
		addon:Lock();
	elseif ( lwr_input == "unlock" ) then
		addon:Unlock();
	elseif ( lwr_input == "debug" ) then
		local seg = addon.SegmentManager:Get(addon.currentSegment);
		if ( seg ) then seg:Debug() end
	elseif (lwr_input == "start" ) then
		addon:StartFight("test");
	end
end



--[[----------------------------------------------------------------------------
	isBFA() - temporary, for supporting 7.3.5 and 8.0 concurrently. 
		      Remove for final release.
------------------------------------------------------------------------------]]
function addon:isBFA()
	local _,_,_,b = GetBuildInfo();
	return b >= 80000;
end



--[[----------------------------------------------------------------------------
Addon Initialized
------------------------------------------------------------------------------]]
function hsw:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HSW_DB", defaults)

	LibStub("AceConfig-3.0"):RegisterOptionsTable("HealerStatWeights",options);
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("HealerStatWeights", "HealerStatWeights");
	self:RegisterChatCommand("hsw","ChatCommand");
end



addon.hsw = hsw;