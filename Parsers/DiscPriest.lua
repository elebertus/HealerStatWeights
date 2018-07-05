local name, addon = ...;



function addon:IsDiscPriest()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.DPRIEST);
end

atonementQueue = addon.SpellQueue.Create(nil);





--[[----------------------------------------------------------------------------
	Disc Priest BFA Mastery
		- Calculated on targets with atonement
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M)
	return 0;
end


local function _DamageEvent(spellInfo,amount)
	if ( spellInfo.transfersToAtonement ) then
		local numAtonement = addon.AtonementCount;
		atonementQueue:Enqueue(numAtonement,spellInfo);
	end
end


local function _HealEvent(ev,spellInfo,heal,overhealing,destUnit,f)
	if ( spellInfo.spellID == addon.DiscPriest.Atonement ) then
		local event = atonementQueue:MatchHeal();
		
		if ( event and event.data ) then
			local cur_seg = addon.SegmentManager:Get(0);
			local ttl_seg = addon.SegmentManager:Get("Total");
			if ( event.data.spellID == addon.DiscPriest.Smite ) then
				--add healing to smite bucket
				--add healing to filler spells bucket
			end
			
			--[[
				if target has atonement from PW:S, add to PW:S bucket			
			]]
			
			
			--[[allocate statweights
			if ( overhealing == 0 ) then
				local _I,_C,_Hhpm,_Hhpct,_M,_V,_L = 0,0,0,0,0,0,0;
				
				_I 	 			= addon.BaseParsers.Intellect(ev,spellInfo,heal,destUnit,event.SP,f);
				_C				= addon.BaseParsers.CriticalStrike(ev,spellInfo,heal,destUnit,event.C,addon.ply_crtbonus,f) ;
				_Hhpm,_Hhpct	= addon.BaseParsers.Haste(ev,spellInfo,heal,destUnit,event.H,f);
				_M	 			= _Mastery(ev,spellInfo,heal,destUnit,event.M,event.ME);
				_V	 			= addon.BaseParsers.Versatility(ev,spellInfo,heal,destUnit,event.V,f);
				_L	 			= addon.BaseParsers.Leech(ev,spellInfo,heal,destUnit,event.L,f);

				--Add derivatives to current & total segments
				if ( cur_seg ) then
					cur_seg:AllocateHeal(_I,_C,_Hhpm,_Hhpct,_V,_M,_L);
				end
				if ( ttl_seg ) then
					ttl_seg:AllocateHeal(_I,_C,_Hhpm,_Hhpct,_V,_M,_L);
				end
				
				addon:UpdateDisplayStats();
			end
			]]
			
		end
		return true; --skip normal computation of healing event
	end
	return false;
end

addon.StatParser:Create(addon.SpellType.HPRIEST,nil,nil,nil,nil,_Mastery,nil,nil);