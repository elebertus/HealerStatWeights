local name,addon = ...;
local hsw = LibStub("AceAddon-3.0"):NewAddon("HealerStatWeights", "AceConsole-3.0", "AceEvent-3.0")
local media = LibStub("LibSharedMedia-3.0");
local lsmlists = AceGUIWidgetLSMlists;


--[[----------------------------------------------------------------------------
Defaults
------------------------------------------------------------------------------]]
local function Color(r,g,b,a)
	local t = {};
	t.r = r;
	t.g = g;
	t.b = b;
	t.a = a or 1;
	return t;
end

local defaults = {
	global = {
		excludeRaidHealingCooldowns=false,
		useHPMoverHPCT=true,
		autoAssignHasteSetting=true,
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
		maxSegments=10,
		back=0,
		front=0,
		historySize=200,
		alwaysShow=false,
		alwaysEnabled=false,
		fontColor=Color(1,1,1,1),
		fontStr=false,
		history={}
	}
}

local historySelected = 0;
local int_label = "Intellect";
local crt_label = "Critical Strike";
local crt2_label = "Critical Strike (+Resurgence)";
local hst_label = "Haste per Cast";
local hst2_label = "Haste per Cast Time (Estimated)";
local hst3_label = "Haste per Cast Time (Upper-bound)";
local vrs_label = "Versatility";
local vrs2_label = "Versatility (+Damage Reduction)";
local mst_label = "Mastery";
local mp5_label = "MP5 (Estimated)";
local lee_label = "Leech";
local cls_label = "Class/Spec";
local num_pattern = "%.3f";
local sgmt_label = "Segment";
local dur_label = "Duration";
local spec_labels = {
	[105] = "Restoration Druid",
	[264] = "Restoration Shaman",
	[257] = "Holy Priest",
	[65] = "Holy Paladin",
	[270] = "Mistweaver Monk",
	[256] = "Discipline Priest"
}
local class_id_lookup = {
	["Restoration Druid"] = {class=11,spec=4},
	["Discipline Priest"] = {class=5,spec=1},
	["Holy Priest"] = {class=5,spec=2},
	["Holy Paladin"] = {class=2,spec=1},
	["Mistweaver Monk"] = {class=10,spec=2},
	["Restoration Shaman"] = {class=7,spec=3},

}


--[[----------------------------------------------------------------------------
Options
------------------------------------------------------------------------------]]
local _TEST=nil;
local options = {
	name = "Healer Stat Weights",
	handler = hsw,
	childGroups = "tab",
	type = "group",
	args = {
		optionsTab = { 
			name = "Options",
			type = "group",
			order = 1,
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
					name = "Always Show Frame",
					type = "toggle",
					desc = "This setting makes the frame ALWAYS show, regardless of content. By default, the frame only shows on enabled content.",
					order = 8,
					width = "full",
					get = function(info) return hsw.db.global.alwaysShow end,
					set = function(info,val) hsw.db.global.alwaysShow=val; addon:AdjustVisibility(); end
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
				resetPosition = {
					name = "Reset Position",
					desc = "Reset the frame's position to the center of the screen.",
					type = "execute",
					order = 12,
					func = function() addon:ResetFramePosition() end
				},
				fontStr = {
					type = "select",
					name = "Font Type",
					dialogControl = "LSM30_Font",
					order = 13,
					values = lsmlists.font,
					get = function(info) return hsw.db.global.fontStr; end,
					set = function(info,val) hsw.db.global.fontStr = val; addon:AdjustFonts() end
				},
				fontColor = {
					name = "Font Color",
					type = "color",
					order = 14,
					get = function(info) return hsw.db.global.fontColor.r,hsw.db.global.fontColor.g,hsw.db.global.fontColor.b,hsw.db.global.fontColor.a end,
					set = function(info,r,g,b,a) 
						hsw.db.global.fontColor = Color(r,g,b,a);
						addon:AdjustFontColor(); 
					end
				},
				headerContentAndDifficulty = {
					name = "Content and Difficulty",
					desc = "These settings control which content and difficulties to calculate statweights for.",
					type = "header",
					order = 20
				},
				enabledAlways = {
					name = "Always Enabled",
					desc = "It's recommended to only use this addon for instanced PVE, but this setting allows you to run the addon for ANY content.",
					type = "toggle",
					order = 21,
					width = "full",
					get = function(info) return hsw.db.global.alwaysEnabled end,
					set = function(info,val) hsw.db.global.alwaysEnabled = val; addon:AdjustVisibility(); end
				},
				enabledInNormalDungeons = {
					name = "Dungeons (Normal)",
					type = "toggle",
					order = 22,
					width = "full",
					disabled = function(info) return hsw.db.global.alwaysEnabled end,
					get = function(info) return hsw.db.global.enabledInNormalDungeons end,
					set = function(info,val) hsw.db.global.enabledInNormalDungeons = val; addon:AdjustVisibility(); end
				},
				enabledInHeroicDungeons = {
					name = "Dungeons (Heroic)",
					type = "toggle",
					order = 23,
					width = "full",
					disabled = function(info) return hsw.db.global.alwaysEnabled end,
					get = function(info) return hsw.db.global.enabledInHeroicDungeons end,
					set = function(info,val) hsw.db.global.enabledInHeroicDungeons = val; addon:AdjustVisibility(); end
				},
				enabledInMythicDungeons = {
					name = "Dungeons (Mythic)",
					type = "toggle",
					order = 24,
					width = "full",
					disabled = function(info) return hsw.db.global.alwaysEnabled end,
					get = function(info) return hsw.db.global.enabledInMythicDungeons end,
					set = function(info,val) hsw.db.global.enabledInMythicDungeons = val; addon:AdjustVisibility(); end
				},
				enabledInMythicPlusDungeons = {
					name = "Dungeons (Mythic+)",
					type = "toggle",
					order = 25,
					width = "full",
					disabled = function(info) return hsw.db.global.alwaysEnabled end,
					get = function(info) return hsw.db.global.enabledInMythicPlusDungeons end,
					set = function(info,val) hsw.db.global.enabledInMythicPlusDungeons = val; addon:AdjustVisibility(); end
				},
				enabledInLfrRaids = {
					name = "Raids (LFR)",
					type = "toggle",
					order = 26,
					width = "full",
					disabled = function(info) return hsw.db.global.alwaysEnabled end,
					get = function(info) return hsw.db.global.enabledInLfrRaids end,
					set = function(info,val) hsw.db.global.enabledInLfrRaids = val; addon:AdjustVisibility(); end
				},
				enabledInNormalRaids = {
					name = "Raids (Normal)",
					type = "toggle",
					order = 27,
					width = "full",
					disabled = function(info) return hsw.db.global.alwaysEnabled end,
					get = function(info) return hsw.db.global.enabledInNormalRaids end,
					set = function(info,val) hsw.db.global.enabledInNormalRaids = val; addon:AdjustVisibility(); end
				},
				enabledInHeroicRaids = {
					name = "Raids (Heroic)",
					type = "toggle",
					order = 28,
					width = "full",
					disabled = function(info) return hsw.db.global.alwaysEnabled end,
					get = function(info) return hsw.db.global.enabledInHeroicRaids end,
					set = function(info,val) hsw.db.global.enabledInHeroicRaids = val; addon:AdjustVisibility(); end
				},
				enabledInMythicRaids = {
					name = "Raids (Mythic)",
					type = "toggle",
					order = 29,
					width = "full",
					disabled = function(info) return hsw.db.global.alwaysEnabled end,
					get = function(info) return hsw.db.global.enabledInMythicRaids end,
					set = function(info,val) hsw.db.global.enabledInMythicRaids = val; addon:AdjustVisibility(); end
				}
			}
		},
		historyTab = {
			name = "History",
			desc = "A list of your 100 most-recent segments.",
			type = "group",
			order = 2,
			args = {
				HistorySelection = {
					name = "Select a Segment",
					type = "select",
					order = 1,
					width = "full",
					style = "dropdown",
					values = function() return addon:GetHistoricalSegmentsList(); end,
					set = function(info,value) historySelected = value; LibStub("AceConfigRegistry-3.0"):NotifyChange("HealerStatWeights"); end,
					get = function(info) return historySelected; end,				
				},
				ClassSpec = {
					name = cls_label,
					type = "input",
					disabled = true,
					width="full",
					order = 2,
					get = function(info) local h = addon.History:Get(historySelected); return tostring(h[cls_label]); end,
				},		
				Int = {
					name = int_label,
					type = "input",
					disabled = true,
					order = 3,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[int_label]); end,
				},				
				Crt = {
					name = crt_label,
					type = "input",
					disabled = true,
					order = 4,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[crt_label]); end,
				},	
				Crt2 = {
					name = crt2_label,
					desc = "Includes an estimation of the value of resurgence on critical strike. Shaman Only.",
					type = "input",
					disabled = true,
					order = 5,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[crt2_label]); end,
				},				
				Hst = {
					name = hst_label,
					type = "input",
					disabled = true,
					order = 6,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[hst_label]); end,
				},
				Hst2 = {
					name = hst2_label,
					type = "input",
					disabled = true,
					order = 7,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[hst2_label]); end,
				},
				mst = {
					name = mst_label,
					type = "input",
					disabled = true,
					order = 8,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[mst_label]); end,
				},
				-- Hst3 = {
					-- name = hst3_label,
					-- type = "input",
					-- disabled = true,
					-- order = 8,
					-- get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[hst3_label]); end,
				-- },
				Vrs = {
					name = vrs_label,
					type = "input",
					disabled = true,
					order = 9,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[vrs_label]); end,
				},
				Vrs2 = {
					name = vrs2_label,
					type = "input",
					disabled = true,
					order = 10,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[vrs2_label]); end,
				},

				lee = {
					name = lee_label,
					type = "input",
					disabled = true,
					order = 11,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[lee_label]); end,
				},
				mp5 = {
					name = mp5_label,
					type = "input",
					disabled = true,
					order = 12,
					get = function(info) local h = addon.History:Get(historySelected); return string.format(num_pattern,h[mp5_label]); end,
				},
				createPawnStringFromHistory = {
					name = "Create Pawn String",
					type = "execute",
					order = 13,
					func = function() addon:CreatePawnStringFromHistory() end
				}
			}
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
		HFA_ENABLE_FOR_TESTING=true;
		addon:Show();
		addon:StartFight("test");
	elseif (lwr_input == "end" ) then
		addon:EndFight();
	end
end



--[[----------------------------------------------------------------------------
	History - store/retrieve historical segments	
------------------------------------------------------------------------------]]
addon.History = addon.Queue.CreateHistoryQueue();
addon.MythicPlusActive = false;
local dungeonCombinedSegment = nil;

local function mergeDungeonSegments(segment)
	local info = segment:GetInstanceInfo();
	
	if not dungeonCombinedSegment then --create empty segment
		local str = info.name;
		if info.level then
			str = str .. " +"..info.level;
		end	
		dungeonCombinedSegment = addon.Segment.Create(str);
		dungeonCombinedSegment:SetupInstanceInfo(true);
		dungeonCombinedSegment:End();
	end
		
	dungeonCombinedSegment:MergeSegment(segment);
end

function addon:TryAddTotalInstanceSegmentToHistory() --handle adding the total dungeon segment
	if ( dungeonCombinedSegment ) then
		self:AddHistoricalSegment(dungeonCombinedSegment);
		dungeonCombinedSegment = nil
	end
end

function addon:AddHistoricalSegment(segment)
    if ( not segment or not segment.t or segment.t.int==0) then
		--dont add empty segments
        return
	end
	
	if ( self:InRaidInstance() and not segment.instance.bossFight ) then
		--dont add trash fights while in a raid instance
		return;
	end
	
	if ( self.MythicPlusActive ) then --try to merge this segment into the current running history
		mergeDungeonSegments(segment);
	end
	local info = segment:GetInstanceInfo();
	
    local h = {};
	local duration = segment:GetDuration() or 0;
	local m = math.floor(duration/60);
	local s = math.floor(duration - m*60);
	local t_str = m..":"..(s<10 and "0" or "")..s;
	local resurg_add = self:IsRestoShaman() and (segment:GetManaRestoreValue()/self.CritConv) or 0;
    local i = GetSpecialization();
	local specId = GetSpecializationInfo(i);
	
	local tab_str = "    ";
	h.tab = info.bossFight and "" or tab_str;
	h.tab = self.MythicPlusActive and h.tab..tab_str or h.tab;
	
	h[sgmt_label] = segment.id;
	h[dur_label] = t_str;
	h[cls_label] = spec_labels[specId] or "Unknown";
	h[int_label] = 1.0;
	h[crt_label] = segment.t.crit/segment.t.int;
	h[crt2_label] = (segment.t.crit+resurg_add)/segment.t.int;
	h[hst_label] = segment:GetHaste()/segment.t.int;
	h[hst2_label] = segment:GetHasteHPCT() / segment.t.int;
	h[hst3_label] = segment.t.haste_hpct / segment.t.int;
	h[vrs_label] = segment.t.vers / segment.t.int;
	h[vrs2_label] = segment.t.vers_dr / segment.t.int;
	h[mst_label] = segment.t.mast / segment.t.int;
	h[lee_label] = segment.t.leech / segment.t.int;
	h[mp5_label] = segment:GetMP5();
	
	self.History:Enqueue(h,segment);
end


local pawnOptionsFrame;
local pawnOptionsWidth = 220;
function addon:GetPawnStringFromHistory()
	local h = addon.History:Get(historySelected);
	if not pawnOptionsFrame or not h then
		return "";
	end
	local t = class_id_lookup[h[cls_label]];
	local class = GetClassInfo(t.class);
	local specId = t.spec;
	
	local int_key = int_label;
	local hst_key = pawnOptionsFrame.haste_dropdown.selectedLabel;
	local crt_key = pawnOptionsFrame.crit_dropdown.selectedLabel;
	local vrs_key = pawnOptionsFrame.vers_dropdown.selectedLabel;
	local mst_key = mst_label;
	local lee_key = lee_label;
	
	return self:GetPawnStringRaw(h[sgmt_label],class,specId,h[int_key],h[crt_key],h[hst_key],h[vrs_key],h[mst_key],h[lee_key]);
end

function addon:CreatePawnStringFromHistory()
	if not pawnOptionsFrame then
		pawnOptionsFrame = CreateFrame("Frame","HSW_CPSFW",UIParent);
		pawnOptionsFrame:SetWidth(pawnOptionsWidth);
		pawnOptionsFrame:SetHeight(128);
		pawnOptionsFrame:SetPoint("CENTER",0,0);
		pawnOptionsFrame:SetFrameStrata("DIALOG");
		pawnOptionsFrame:SetMovable(true);
		pawnOptionsFrame:EnableMouse(true);
		pawnOptionsFrame:RegisterForDrag("LeftButton");
		pawnOptionsFrame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
												edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
												tile = true, tileSize = 16, edgeSize = 16, 
												insets = { left = 4, right = 4, top = 4, bottom = 4 }});
		pawnOptionsFrame:SetBackdropColor(0,0,0,1);

			
		local function addMenuButton(frame,label)
			local info = UIDropDownMenu_CreateInfo();
			info.checked = (label == frame.selectedLabel);
			info.func = function() frame.selectedLabel = label; UIDropDownMenu_SetText(frame,label); CloseDropDownMenus(); end
			info.text = label;
			UIDropDownMenu_AddButton(info,1);
		end
		local function SetupDropdownMenu(labels)	
			local dropdown = CreateFrame("Frame", "HSW_CPSFH_"..labels[1], pawnOptionsFrame, "UIDropDownMenuTemplate");
			local function init(self,level)
				if ( level == 1 ) then
					for i,v in ipairs(labels) do
						addMenuButton(dropdown,v);
					end		
				end	
			end
			
			dropdown.selectedLabel = labels[1];
			UIDropDownMenu_SetText(dropdown,labels[1]);
			UIDropDownMenu_SetWidth(dropdown, pawnOptionsWidth-50, 8);
			UIDropDownMenu_Initialize(dropdown,init);
			return dropdown;
		end;
		
		local haste_labels = {hst_label,hst2_label};
		local crit_labels = {crt_label,crt2_label};
		local vers_labels = {vrs_label,vrs2_label};
		local haste_dropdown = SetupDropdownMenu(haste_labels);
		haste_dropdown:ClearAllPoints();
		haste_dropdown:SetPoint("TOPLEFT",0,-8);
		pawnOptionsFrame.haste_dropdown = haste_dropdown;
		
		local crit_dropdown = SetupDropdownMenu(crit_labels);
		crit_dropdown:ClearAllPoints();
		crit_dropdown:SetPoint("TOPLEFT",0,-32);
		pawnOptionsFrame.crit_dropdown = crit_dropdown;
		
		local vers_dropdown = SetupDropdownMenu(vers_labels);
		vers_dropdown:ClearAllPoints();
		vers_dropdown:SetPoint("TOPLEFT",0,-56);
		pawnOptionsFrame.vers_dropdown = vers_dropdown;
		
		
		local btn_cancel = CreateFrame("Button","HSW_CPSFH_Cancel",pawnOptionsFrame,"UIPanelButtonTemplate");
		btn_cancel:SetPoint("BOTTOMRIGHT",-8,8);
		btn_cancel:SetHeight(24);
		btn_cancel:SetWidth(pawnOptionsWidth/2-16);
		btn_cancel:SetNormalFontObject("GameFontNormalSmall");
		btn_cancel:SetText("Cancel");
		btn_cancel:SetScript("OnClick",function() 
			pawnOptionsFrame:Hide();
		end);
		
		local btn_accept = CreateFrame("Button","HSW_CPSFH_Accept",pawnOptionsFrame,"UIPanelButtonTemplate");
		btn_accept:SetPoint("BOTTOMLEFT",8,8);
		btn_accept:SetHeight(24);
		btn_accept:SetWidth(pawnOptionsWidth/2-16);
		btn_accept:SetNormalFontObject("GameFontNormalSmall");
		btn_accept:SetText("Create!");
		btn_accept:SetScript("OnClick",function()
			pawnOptionsFrame:Hide();
			StaticPopup_Show(addon.PawnHistoryDialogName);
		end);
	end
	
	pawnOptionsFrame:Show();
end

local function addExampleSegment()
	local s = addon.Segment.Create("Example Segment!");
	s:AllocateHeal(1,math.random(),math.random(),math.random(),math.random(),math.random(),math.random(),math.random(),math.random());
	s:AllocateHealDR(math.random()*0.1);
	addon:AddHistoricalSegment(s);
end

function addon:GetHistoricalSegmentsList()
	local t = {};
	local n = addon.History:Size();
	local h;
	
	if ( n == 0 ) then
		addExampleSegment();
		n = addon.History:Size();
	end
	
	for i=0,n-1,1 do
		h = addon.History:Get(i);
		if ( h ) then
			t[i] = (h.tab or "") .. h[sgmt_label] .. " " .. h[dur_label];
		end
	end
	
	return t;
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