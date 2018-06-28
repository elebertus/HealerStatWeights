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

local cloudburst_buff = 157504;
local cloudburst_explosion = 157503;

local function _HealEvent(ev,spellInfo,heal,overhealing,destUnit)	
	local cloudburst_totem = addon.BuffTracker:Get(cloudburst_buff);
	
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

StartCBT();
addon.BuffTracker:Track(cloudburst_buff,StartCBT,nil); --cloudburst totem



--[[----------------------------------------------------------------------------
	Resto Shaman Spell Power
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
local function _Intellect(ev,spellInfo,heal,destUnit,SP)
	if ( spellInfo.spellID == cloudburst_explosion ) then
		SP = cbt.sp_times_heal / cbt.heal;
	end
	
	return addon.BaseParsers.Intellect(ev,spellInfo,heal,destUnit,SP,nil);
end


--[[----------------------------------------------------------------------------
	Resto Shaman Critical Strike
		- modified by tidal waves on healing surge
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
addon.ShamanTidalWaves = 53390;
addon.ShamanHealingSurge = 8004;
addon.BuffTracker:Track(addon.ShamanTidalWaves,nil,nil); 

local function _CriticalStrike(ev,spellInfo,heal,destUnit,C,CB)	
	if ( spellInfo.spellID == cloudburst_explosion ) then
		C = cbt.crit_times_heal / cbt.heal;
	end

	if ( spellInfo.spellID == addon.ShamanHealingSurge ) then
		if ( addon.BuffTracker:Get(addon.ShamanTidalWaves) > 0 ) then
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
	if ( spellInfo.spellID == cloudburst_explosion ) then
		H = cbt.haste_times_heal / cbt.heal;
	end
	
	return addon.BaseParsers.Haste(ev,spellInfo,heal,destUnit,H,nil);
end



--[[----------------------------------------------------------------------------
	Resto Shaman Versatility
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
local function _Versatility(ev,spellInfo,heal,destUnit,V)	
	if ( spellInfo.spellID == cloudburst_explosion ) then
		V = cbt.vers_times_heal / cbt.heal;
	end
	
	return addon.BaseParsers.Versatility(ev,spellInfo,heal,destUnit,V,nil);
end



--[[----------------------------------------------------------------------------
	Resto Shaman Mastery
		- Mastery effect is based on % hp on target
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M)
	if ( spellInfo.spellID == cloudburst_explosion ) then
		M = cbt.mast_times_heal / cbt.heal;
		local ME = cbt.masteffect_times_heal / cbt.heal;
		return ME*heal / (1+ME*M) / addon.MasteryConv;
	end
	
	if ( spellInfo.mst ) then	
		local ME = getMasteryEffect(destUnit);
		return ME*heal / (1+ME*M) / addon.MasteryConv;
	end
	
	return 0;
end



addon.StatParser:Create(addon.SpellType.SHAMAN,_Intellect,_CriticalStrike,_Haste,_Versatility,_Mastery,nil,_HealEvent);