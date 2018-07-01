local name, addon = ...;



function addon:IsMistweaverMonk()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.MONK);
end



--[[----------------------------------------------------------------------------
	Mistweaver Monk Mastery
		- calculated from Gust of Mists healing (similar to Hpriest Echo of Light)
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M)
	if ( spellinfo.spellID == addon.Monk.GustOfMists ) then
		if ( M == 0 ) then
			return 0;
		end
		return heal / M / addon.MasteryConv;
	end
	return 0;
end



addon.StatParser:Create(addon.SpellType.MONK,nil,nil,nil,nil,_Mastery,nil,nil);