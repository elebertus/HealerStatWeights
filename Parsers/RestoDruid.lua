local name, addon = ...;



function addon:IsRestoDruid()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.DRUID);
end



--[[----------------------------------------------------------------------------
	hotCount() - get the resto druid mastery effect (hotcount)
------------------------------------------------------------------------------]]
local hots = { --spells that count towards druid mastery stacks
	[addon.Druid.TranquilityHoT]=true,
	[addon.Druid.Rejuvenation]=true,
	[addon.Druid.Germination]=true,
	[addon.Druid.LifebloomHoT]=true,
	[addon.Druid.Regrowth]=true, --regrowth
	[addon.Druid.WildGrowth]=true,
	[addon.Druid.SpringBlossoms]=true,
	[addon.Druid.Cultivation]=true,
	[addon.Druid.CenarionWard]=true,
	[addon.Druid.DreamerHoT]=true
}

local function hotCount(unit)
	local count = 0;
	for i=1,40,1 do
		local _,id;
		
		if ( addon:isBFA() ) then
			_,_,_,_,_,_,p,_,_,id = UnitAura(unit,i);
		else
			_,_,_,_,_,_,_,p,_,_,id = UnitAura(unit,i);
		end
		
		if ( not id ) then
			break;
		elseif (p == "player" and hots[id]) then
			count = count + 1;
		end
	end
	
	return count;
end



--[[----------------------------------------------------------------------------
	Druid Critical Strike 
		- modified by abundance on regrowth
------------------------------------------------------------------------------]]
local function _CriticalStrike(ev,spellInfo,heal,destUnit,C,CB)
	
	if ( spellInfo.spellID == addon.Druid.Regrowth ) then
		local abundance = addon.BuffTracker:Get(addon.Druid.AbundanceBuff);
		if ( addon:isBFA() ) then
			C = C + (abundance * 0.06);
		else
			C = C + 0.4 + (abundance * 0.10);
		end
	end
	
	return addon.BaseParsers.CriticalStrike(ev,spellInfo,heal,destUnit,C,CB,nil);
end



--[[----------------------------------------------------------------------------
	Druid Mastery 
		- modified by hotcount on target
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M)
	if ( spellInfo.mst ) then --spell is affected by mastery, get the hotCount on target.		
		local count = hotCount(destUnit);
		return count*heal / (1+count*M) / addon.MasteryConv;
	end
	return 0;
end



addon.StatParser:Create(addon.SpellType.DRUID,nil,_CriticalStrike,nil,nil,_Mastery,nil,nil);