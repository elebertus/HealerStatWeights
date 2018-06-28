local name, addon = ...;



function addon:IsHolyPriest()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.HPRIEST);
end



--[[----------------------------------------------------------------------------
	Holy Priest Mastery
		- calculated from echo of light healing
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M)
	if ( spellInfo.spellID == 77489 ) then --echo of light healing
		if ( M == 0 ) then
			return 0;
		end
		return heal / M / addon.MasteryConv; --divide by M instead of (1+M)
	end
	return 0;
end



addon.StatParser:Create(addon.SpellType.HPRIEST,nil,nil,nil,nil,_Mastery,nil,nil);