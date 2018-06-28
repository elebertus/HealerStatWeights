local name, addon = ...;


addon.BuffTracker:Track(207383) --abundance




function addon:IsRestoDruid()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.DRUID);
end



--[[----------------------------------------------------------------------------
	hotCount() - get the resto druid mastery effect (hotcount)
------------------------------------------------------------------------------]]
local hots = { --spells that count towards druid mastery stacks
	[157982]=true,
	[774]=true,
	[155777]=true,
	[33763]=true,
	[8936]=true, --regrowth
	[48438]=true,
	[207386]=true,
	[200389]=true,
	[102352]=true,
	[253432]=true
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
	
	if ( spellInfo.spellID == 8936 ) then
		local abundance = addon.BuffTracker:Get(207383);
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