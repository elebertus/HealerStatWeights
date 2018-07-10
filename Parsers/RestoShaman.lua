local name, addon = ...;


function addon:IsRestoShaman()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.SHAMAN);
end



--[[----------------------------------------------------------------------------
	getMasteryEffect - Resto shaman mastery scales basesd on missing % health of target unit
------------------------------------------------------------------------------]]
local function getMasteryEffect(destUnit)
	if ( destUnit ) then
		local max_hp = UnitHealthMax(destUnit)
		if ( max_hp and max_hp > 0 ) then
			return (max_hp - UnitHealth(destUnit))/max_hp;
		end
	end
	return 0;
end



--[[----------------------------------------------------------------------------
	Ascendance - Spell queue & Buff tracking
------------------------------------------------------------------------------]]
local ascendanceQueue = addon.Queue.CreateSpellQueue(getMasteryEffect);
addon.BuffTracker:Track(addon.Shaman.AscendanceBuff);



--[[----------------------------------------------------------------------------
	Cloud Burst Totem
		Track weighted average of stat percentages on healing that feeds the
		cloudburst totem. These weighted averages can then be used by the
		decomp function.
------------------------------------------------------------------------------]]
local cbt = {};

local function StartCBT()	
	cbt.sp_times_heal = 0;
	cbt.crit_times_heal = 0;
	cbt.haste_times_heal = 0;
	cbt.vers_times_heal = 0;
	cbt.mast_times_heal = 0;
	cbt.masteffect_times_heal = 0;
	cbt.heal = 0.0001;
end

StartCBT();
addon.BuffTracker:Track(addon.Shaman.CloudburstBuff,StartCBT,nil); --cloudburst totem



--[[----------------------------------------------------------------------------
	Resto Shaman Spell Power
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
local function _Intellect(ev,spellInfo,heal,destUnit,SP)
	if ( spellInfo.spellID == addon.Shaman.CloudburstHeal ) then
		SP = cbt.sp_times_heal / cbt.heal;
	end
	
	return addon.BaseParsers.Intellect(ev,spellInfo,heal,destUnit,SP,nil);
end


--[[----------------------------------------------------------------------------
	Resto Shaman Critical Strike
		- modified by tidal waves on healing surge
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
local function _CriticalStrike(ev,spellInfo,heal,destUnit,C,CB)	
	if ( spellInfo.spellID == addon.Shaman.CloudburstHeal ) then
		C = cbt.crit_times_heal / cbt.heal;
	elseif ( spellInfo.spellID == addon.Shaman.HealingSurge ) then
		if ( addon.BuffTracker:Get(addon.Shaman.TidalWavesBuff) > 0 ) then
			C = C + 0.4;
		end
	end
	
	return addon.BaseParsers.CriticalStrike(ev,spellInfo,heal,destUnit,C,CB,nil);
end



--[[----------------------------------------------------------------------------
	Resto Shaman Haste
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
local function _Haste(ev,spellInfo,heal,destUnit,H)	
	if ( spellInfo.spellID == addon.Shaman.CloudburstHeal ) then
		H = cbt.haste_times_heal / cbt.heal;
	end
	
	return addon.BaseParsers.Haste(ev,spellInfo,heal,destUnit,H,nil);
end



--[[----------------------------------------------------------------------------
	Resto Shaman Versatility
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
local function _Versatility(ev,spellInfo,heal,destUnit,V)	
	if ( spellInfo.spellID == addon.Shaman.CloudburstHeal ) then
		V = cbt.vers_times_heal / cbt.heal;
	end
	
	return addon.BaseParsers.Versatility(ev,spellInfo,heal,destUnit,V,nil);
end



--[[----------------------------------------------------------------------------
	Resto Shaman Mastery
		- Mastery effect is based on % hp on target
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M,ME_ascendance)
	local ME;
	
	if ( spellInfo.spellID == addon.Shaman.CloudburstHeal ) then
		M = cbt.mast_times_heal / cbt.heal;
		ME = cbt.masteffect_times_heal / cbt.heal;
		return ME*heal / (1+ME*M) / addon.MasteryConv;
	end
	
	if not spellInfo.mst then
		return 0;
	end
	
	if ME_ascendance then
		ME = ME_ascendance;
	else
		ME = getMasteryEffect(destUnit);
	end
	
	return ME*heal / (1+ME*M) / addon.MasteryConv;
end



--[[----------------------------------------------------------------------------
	Heal Event - Ascendance & CBT tracking
------------------------------------------------------------------------------]]
local function _HealEvent(ev,spellInfo,heal,overhealing,destUnit)	
	--Ascendance
	if (spellInfo.spellID == addon.Shaman.Ascendance) then
		local event = ascendanceQueue:MatchHeal();
		
		if ( event ) then
			local cur_seg = addon.SegmentManager:Get(0);
			local ttl_seg = addon.SegmentManager:Get("Total");
			
			if ( overhealing == 0 ) then
				local _I,_C,_Hhpm,_Hhpct,_M,_V,_L = 0,0,0,0,0,0,0;
				_I 	 			= _Intellect(ev,spellInfo,heal,destUnit,event.SP);
				_C				= _CriticalStrike(ev,spellInfo,heal,destUnit,event.C,addon.ply_crtbonus) ;
				_Hhpm,_Hhpct	= _Haste(ev,spellInfo,heal,destUnit,event.H);
				_M	 			= _Mastery(ev,spellInfo,heal,destUnit,event.M,event.ME);
				_V	 			= _Versatility(ev,spellInfo,heal,destUnit,event.V);
				_L	 			= _Leech(ev,spellInfo,heal,destUnit,event.L);

				--Add derivatives to current & total segments
				if ( cur_seg ) then
					cur_seg:AllocateHeal(_I,_C,_Hhpm,_Hhpct,_V,_M,_L);
				end
				if ( ttl_seg ) then
					ttl_seg:AllocateHeal(_I,_C,_Hhpm,_Hhpct,_V,_M,_L);
				end
				
				addon:UpdateDisplayStats();
			end
			
			if ( event.filler ) then
				if ( cur_seg ) then
					cur_seg:IncFillerHealing(heal);
				end
				if ( ttl_seg ) then
					ttl_seg:IncFillerHealing(heal);
				end
			end
		end
		return true;
	elseif ( addon.BuffTracker:Get(addon.Shaman.AscendanceBuff) > 0 ) then
		ascendanceQueue:Enqueue(3,spellInfo.filler,destUnit);
	end
	
	--CBT
	local cloudburst_totem = addon.BuffTracker:Get(addon.Shaman.CloudburstBuff);
	if ( cloudburst_totem > 0 ) then
		
		local total_heal = heal+overhealing;
		if ( spellInfo.mst ) then
			cbt.mast_times_heal = cbt.mast_times_heal + addon.ply_mst * total_heal;
			cbt.masteffect_times_heal = cbt.masteffect_times_heal + getMasteryEffect(destUnit) * total_heal;
		end
		
		if ( spellInfo.int ) then
			cbt.sp_times_heal = cbt.sp_times_heal + (addon.ply_sp) * total_heal;
		end
		
		if ( spellInfo.crt ) then
			cbt.crit_times_heal = cbt.crit_times_heal + (addon.ply_crt) * total_heal;
		end
		
		if ( spellInfo.hstHPCT ) then
			cbt.haste_times_heal = cbt.haste_times_heal + (addon.ply_hst) * total_heal;
		end
		
		if ( spellInfo.vrs ) then
			cbt.vers_times_heal = cbt.vers_times_heal + (addon.ply_vrs) * total_heal;
		end
		
		cbt.heal = cbt.heal + total_heal;
	end
end




addon.StatParser:Create(addon.SpellType.SHAMAN,_Intellect,_CriticalStrike,_Haste,_Versatility,_Mastery,nil,_HealEvent);